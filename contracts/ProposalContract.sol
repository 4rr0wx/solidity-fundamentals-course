// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract ProposalContract {
    uint256 private counter;
    using ProposalTally for Proposal;

    enum Vote {
        Approve,
        Reject,
        Pass
    }

    struct Proposal {
        string description; // Description of the proposal
        uint256 approve; // Number of approve votes
        uint256 reject; // Number of reject votes
        uint256 pass; // Number of pass votes
        uint256 total_vote_to_end; // When the total votes in the proposal reaches this limit, proposal ends
        bool current_state; // This shows the current state of the proposal, meaning whether if passes of fails
        bool is_active; // This shows if others can vote to our contract
    }

    address public immutable owner;

    uint256[] public proposalIds;
    mapping(uint256 => Proposal) private proposal_history;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(uint256 indexed id, uint256 voteLimit);
    event ProposalClosed(uint256 indexed id, bool approved);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can create proposals");
        _;
    }

    modifier existingProposal(uint256 id) {
        require(id > 0 && id <= proposalIds.length, "Unknown proposal");
        _;
    }

function create(string calldata _description, uint256 _total_vote_to_end)
    external
    onlyOwner
{
    require(_total_vote_to_end > 0, "Vote limit must be positive");

    counter += 1;
    proposal_history[counter] = Proposal(
        _description,
        0,
        0,
        0,
        _total_vote_to_end,
        false,
        true
    );

    proposalIds.push(counter);
    emit ProposalCreated(counter, _total_vote_to_end);
}

    function vote(uint256 id, Vote choice) external existingProposal(id) {
        Proposal storage proposal = proposal_history[id];

        require(proposal.is_active, "Proposal is closed");
        require(msg.sender != owner, "Owner cannot vote");
        require(!hasVoted[id][msg.sender], "Already voted");

        hasVoted[id][msg.sender] = true;

        if (choice == Vote.Approve) {
            proposal.approve += 1;
        } else if (choice == Vote.Reject) {
            proposal.reject += 1;
        } else {
            proposal.pass += 1;
        }

        proposal.current_state = proposal.isPassing();

        if (proposal.totalVotes() == proposal.total_vote_to_end) {
            proposal.is_active = false;
            emit ProposalClosed(id, proposal.current_state);
        }
    }

    function proposalCount() external view returns (uint256) {
        return proposalIds.length;
    }

    function getProposal(uint256 id)
        external
        view
        existingProposal(id)
        returns (Proposal memory)
    {
        return proposal_history[id];
    }
}

library ProposalTally {
    function isPassing(ProposalContract.Proposal storage proposal)
        internal
        view
        returns (bool)
    {
        return proposal.approve > proposal.reject;
    }

    function totalVotes(ProposalContract.Proposal storage proposal)
        internal
        view
        returns (uint256)
    {
        return proposal.approve + proposal.reject + proposal.pass;
    }
}