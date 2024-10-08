enum lobbyOp {
    SERVER_PING = 0,
    CLIENT_VOTE = 1,
    SERVER_VOTE_DATA = 2,
    SERVER_MATCH_DATA = 3,
    SERVER_ABORT = 4,
}


const lobbyMatchInit = function (ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, params: { [key: string]: string }): { state: nkruntime.MatchState, tickRate: number, label: string } {
    // logger.debug("Matchinit");

    logger.debug("Inside Matchinit. MatchType: " + params.matchType)

    let tickRate = 4;

    let joinable = 1;
    let players = 0;
    let presences = {};
    let userData = {} as { [key: string]: any };
    let prevUserIds: string[] = [];

    if ('fromMatch' in params){
        presences = JSON.parse(params.fromMatch);
        prevUserIds = Object.keys(presences);
        players = prevUserIds.length;

        prevUserIds.forEach(function (userId) {
            userData[userId] = nk.accountGetId(userId).user.metadata;
        });
    }

    let label: label = {
        version: params.version,
        matchType: params.matchType,
        joinable: joinable,
        players: players,
        maxPlayers: 12,
    }

    // let voteTimeout = 30 * tickRate;
    let voteTimeout = 60 * tickRate;
    let joinTimeout = 45 * tickRate;
    let openTimeout = 30 * tickRate;
    let ultimateTimeout = 600 * tickRate;

    if (!prevUserIds.length) {
        voteTimeout -= openTimeout;
        joinTimeout -= openTimeout;
        openTimeout = 0;
    }

    let joinedIds: String[] = [];

    return {
        state: {
            presences: presences,
            userData: userData,
            prevUserIds: prevUserIds,
            joinedIds: joinedIds,
            emptyTicks: 0,
            nextMatchType: params.nextMatchType,
            votes: {},
            voteTimeout: voteTimeout,
            joinTimeout: joinTimeout,
            openTimeout: openTimeout,
            expireTimeout: voteTimeout*2,
            ultimateTimeout: ultimateTimeout,
            label: label,
            pingData: {},
            skipVote: false,
            voteComplete: false,
        },
        tickRate: tickRate,
        label: '{}'
    };
};

const lobbyMatchJoinAttempt = function (ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, dispatcher: nkruntime.MatchDispatcher, tick: number, state: nkruntime.MatchState, presence: nkruntime.Presence, metadata: { [key: string]: any }): { state: nkruntime.MatchState, accept: boolean, rejectMessage?: string | undefined } | null {
    // logger.debug("MatchJoinAttempt", presence.userId);

    if (state.label.players >= state.label.maxPlayers) {
        return {
            state,
            accept: false,
            rejectMessage: "Match is full"
        };
    }

    return {
        state,
        accept: true
    };
}

const lobbyMatchJoin = function (ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, dispatcher: nkruntime.MatchDispatcher, tick: number, state: nkruntime.MatchState, presences: nkruntime.Presence[]): { state: nkruntime.MatchState } | null {
    presences.forEach(function (p) {
        state.joinedIds.push(p.userId);

        if (p.userId in state.presences) {
            state.presences
        }

        state.presences[p.userId] = p;
        state.userData[p.userId] = nk.accountGetId(p.userId).user.metadata;
    });

    updateLabel(state, dispatcher)

    return {
        state
    };
}

const lobbyMatchLeave = function (ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, dispatcher: nkruntime.MatchDispatcher, tick: number, state: nkruntime.MatchState, presences: nkruntime.Presence[]): { state: nkruntime.MatchState } | null {
    presences.forEach(function (p) {
        let idx = state.joinedIds.indexOf(p.userId);
        if (idx > -1) {
            state.joinedIds.splice(idx, 1);
        }
        idx = state.prevUserIds.indexOf(p.userId);
        if (idx > -1) {
            state.prevUserIds.splice(idx, 1);
        }
        
        delete state.presences[p.userId];
        delete state.pingData[p.userId];
        delete state.votes[p.userId];
        updateLabel(state, dispatcher)
    });

    return {
        state
    };
}

const lobbyMatchLoop = function (ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, dispatcher: nkruntime.MatchDispatcher, tick: number, state: nkruntime.MatchState, messages: nkruntime.MatchMessage[]): { state: nkruntime.MatchState } | null {
    // logger.info("Match loop " + state.emptyTicks);
    // logger.info("Amount of presences: " + Object.keys(state.presences).length)

    // If there are less than 2 players, don't start the match
    // TODO: A player can be "stuck" and the server keeps pinging them forever. Add some check for the last received ping and kick them.
    if (tick >= state.joinTimeout && Object.keys(state.presences).length == 1) {
        // Extend the timeouts.
        state.voteTimeout += 30 * ctx.matchTickRate;
        state.joinTimeout += 30 * ctx.matchTickRate;
        state.expireTimeout += 30 * ctx.matchTickRate;
        updateJoinableStatus(tick, state, dispatcher);
    }

    if (!state.voteComplete) {
        updateJoinableStatus(tick, state, dispatcher);

        pingUsers(lobbyOp.SERVER_PING, tick, ctx, state, dispatcher);
    
        let trueVoteTimeout = state.voteTimeout + 3 * ctx.matchTickRate; // 3 seconds buffer
    
        if (tick == trueVoteTimeout || (state.skipVote && tick >= state.joinTimeout)) {
            state.voteComplete = true;
            startNextMatch(state, dispatcher, nk);
        }
    
        if (tick < trueVoteTimeout) {
            // Loop over all messages received by the match
            processMessages(messages, nk, state, logger, tick, ctx, dispatcher);
        }

        if (tick == state.openTimeout) {
            // Remove slots reserved for users from previous match who didn't join
            for (let userId of state.prevUserIds) {
                if (!(userId in state.presences)) {
                    delete state.presences[userId];
                }
            }
            state.prevUserIds = [];
            updateLabel(state, dispatcher);
        }
    }


    if (tick > state.expireTimeout) {
        return null;
    }

    if (tick > state.ultimateTimeout) {
        return null;
    }

    return {
        state
    };
}

const lobbyMatchSignal = function (ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, dispatcher: nkruntime.MatchDispatcher, tick: number, state: nkruntime.MatchState, data: string): { state: nkruntime.MatchState, data?: string } | null {
    // logger.debug('Lobby match signal received: ' + data);

    return {
        state,
        data: "Lobby match signal received: " + data
    };
}

const lobbyMatchTerminate = function (ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, dispatcher: nkruntime.MatchDispatcher, tick: number, state: nkruntime.MatchState, graceSeconds: number): { state: nkruntime.MatchState } | null {
    logger.info('Starting graceful termination');

    return {
        state
    };
}

function processMessages(messages: nkruntime.MatchMessage[], nk: nkruntime.Nakama, state: nkruntime.MatchState, logger: nkruntime.Logger, tick: number, ctx: nkruntime.Context, dispatcher: nkruntime.MatchDispatcher) {
    messages.forEach(function (message) {
        // Extract the operation code and payload from the message
        const opCode = message.opCode;
        const payload = message.data;
        const data = JSON.parse(nk.binaryToString(payload));
        const presence = message.sender;

        if (!(presence.userId in state.presences)) {
            return;
        }

        // Handle the operation code
        switch (opCode) {
            case lobbyOp.SERVER_PING:
                handle_ping_message(message, data, presence, state, dispatcher);
                break;
            case lobbyOp.CLIENT_VOTE:
                handle_vote_message(message, data, presence, state);
                break;
            default:
                logger.warn("Unrecognized operation code", opCode);
                break;
        }
    });

    var pingDict: { [key: string]: number; } = {};
    for (let userId in state.pingData) {
        pingDict[userId] = state.pingData[userId].ping;
    }

    var vote_data = {
        votes: state.votes,
        presences: state.presences,
        tick: tick,
        voteTimeout: state.voteTimeout,
        tickRate: ctx.matchTickRate,
        pingData: pingDict,
        userData: state.userData
    };

    // Broadcast all votes to all presences
    dispatcher.broadcastMessage(lobbyOp.SERVER_VOTE_DATA, JSON.stringify(vote_data), null, null);
}

function handle_vote_message(message: nkruntime.MatchMessage, data: any, presence: nkruntime.Presence, state: nkruntime.MatchState) {
    state.votes[presence.userId] = data;

    // Check if all presences have voted
    let presences = Object.keys(state.presences).map((key) => state.presences[key]);
    let votes = Object.keys(state.votes);
    
    var allVoted = true;
    presences.forEach(function (p) {
        if (!(p.userId in state.votes)) {
            allVoted = false;
        }
    });

    if (allVoted) {
        state.skipVote = true;
    }
}


function startNextMatch(state: nkruntime.MatchState, dispatcher: nkruntime.MatchDispatcher, nk: nkruntime.Nakama) {
    // Start the match

    // Kick users who haven't voted evern after grace period
    let presences = Object.keys(state.presences).map((key) => state.presences[key]);
    presences.forEach(function (p: nkruntime.Presence) {
        if (!(p.userId in state.votes)) {
            dispatcher.matchKick([p]);
        }
    });

    // Pick a random user's vote.
    let keys = Object.keys(state.votes);
    let randomIndex = Math.floor(Math.random() * keys.length);
    let randomKey = keys[randomIndex];
    let randomVote = state.votes[randomKey];
    let startingIds = Object.keys(state.presences);  // This will indicate the starting order.

    // Create a race match using this course
    let matchId = nk.matchCreate(state.nextMatchType, { matchType: state.nextMatchType, version: state.label.version, winningVote: JSON.stringify(randomVote), startingIds: JSON.stringify(startingIds) });

    let payload = {
        matchId: matchId,
        winningVote: randomVote,
        voteUser: randomKey,
        startingIds: startingIds
    }

    // Broadcast the new match to all presences
    dispatcher.broadcastMessage(lobbyOp.SERVER_MATCH_DATA, JSON.stringify(payload), null, null);
}


function updateJoinableStatus(tick: number, state: nkruntime.MatchState, dispatcher: nkruntime.MatchDispatcher) {
    if (tick > state.joinTimeout) {
        state.label.joinable = 0;
        updateLabel(state, dispatcher);
    }
}
