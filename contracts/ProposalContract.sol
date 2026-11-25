// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract ProposalContract {
    using ProposalTally for Proposal;

    uint256 private counter;

    enum Vote {
        Approve,
        Reject,
        Pass
    }

    struct Proposal {
        string title;
        string description;
        uint256 approve;
        uint256 reject;
        uint256 pass;
        uint256 total_vote_to_end;
        bool current_state;
        bool is_active;
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

    modifier active(uint256 id) {
        require(proposal_history[id].is_active, "The proposal is not active");
        _;
    }

    modifier newVoter(uint256 id) {
        require(!hasVoted[id][msg.sender], "Address has already voted");
        _;
    }

    function create(
        string calldata _title,
        string calldata _description,
        uint256 _total_vote_to_end
    ) external onlyOwner {
        require(_total_vote_to_end > 0, "Vote limit must be positive");

        counter += 1;
        proposal_history[counter] = Proposal({
            title: _title,
            description: _description,
            approve: 0,
            reject: 0,
            pass: 0,
            total_vote_to_end: _total_vote_to_end,
            current_state: false,
            is_active: true
        });

        proposalIds.push(counter);
        emit ProposalCreated(counter, _total_vote_to_end);
    }

    function vote(uint256 id, Vote choice)
        external
        existingProposal(id)
        active(id)
        newVoter(id)
    {
        Proposal storage proposal = proposal_history[id];

        require(msg.sender != owner, "Owner cannot vote");

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
        uint256 halfPassRoundedUp = (proposal.pass / 2) + (proposal.pass % 2);
        return proposal.approve > proposal.reject + halfPassRoundedUp;
    }

    function totalVotes(ProposalContract.Proposal storage proposal)
        internal
        view
        returns (uint256)
    {
        return proposal.approve + proposal.reject + proposal.pass;
    }
}