// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RQ {
    enum PaperStage { Approved, Rejected, Published }

    struct Paper {
        string title;
        string author;
        string content;
        uint256 timestamp;
        uint256 quadraticFunding;
        uint256 totalPositiveWeight;
        uint256 totalNegativeWeight;
        bool isReproducible;
        PaperStage stage;
        mapping(address => bool) owners;
        mapping(address => bool) hasVoted;
        address walletAddress;
    }

    mapping(uint256 => Paper) public papers;
    uint256 public paperCount;

    mapping(address => bool) public members;

    event PaperUploaded(uint256 indexed paperId, string title, string author, uint256 timestamp, PaperStage stage);
    event PaperStageUpdated(uint256 indexed paperId, PaperStage stage);
    event QuadraticFundingUpdated(uint256 indexed paperId, uint256 quadraticFunding);

    constructor() {
        // Add the DAO members during contract deployment
        members[msg.sender] = true;
        // Add more members if needed
    }

    modifier onlyMembers() {
        require(members[msg.sender], "Only members can call this function");
        _;
    }

    function addMember(address member) external onlyMembers {
        members[member] = true;
    }

    function removeMember(address member) external onlyMembers {
        members[member] = false;
    }

    function uploadPaper(
        string memory title,
        string memory author,
        string memory content,
        uint256 quadraticFunding,
        bool isReproducible,
        PaperStage stage,
        address walletAddress
    ) external {
        uint256 timestamp = block.timestamp;
        uint256 paperId = paperCount + 1;

        Paper storage newPaper = papers[paperId];
        newPaper.title = title;
        newPaper.author = author;
        newPaper.content = content;
        newPaper.timestamp = timestamp;
        newPaper.isReproducible = isReproducible;
        newPaper.stage = stage;
        newPaper.walletAddress = walletAddress;
        newPaper.quadraticFunding = quadraticFunding; // Initialize quadratic funding
        newPaper.totalPositiveWeight = 0;
        newPaper.totalNegativeWeight = 0;
        papers[paperId].owners[msg.sender] = true;
        paperCount++;

        emit PaperUploaded(paperId, title, author, timestamp, stage);
    }

    function updatePaperStage(uint256 paperId, PaperStage stage) public onlyMembers {
        require(paperId <= paperCount, "Invalid paperId");
        papers[paperId].stage = stage;

        emit PaperStageUpdated(paperId, stage);
    }

    function addPaperOwner(uint256 paperId, address newOwner) external onlyMembers {
        require(paperId <= paperCount, "Invalid paperId");
        papers[paperId].owners[newOwner] = true;
    }

    function removePaperOwner(uint256 paperId, address owner) external onlyMembers {
        require(paperId <= paperCount, "Invalid paperId");
        require(papers[paperId].owners[owner], "Owner does not exist for this paper");
        papers[paperId].owners[owner] = false;
    }

    // Quadratic funding functions

    function calculateQuadraticFunding(uint256 paperId) internal {
        Paper storage paper = papers[paperId];
        uint256 totalWeight = paper.totalPositiveWeight + paper.totalNegativeWeight;

        if (totalWeight == 0) {
            paper.quadraticFunding = 0;
        } else {
            uint256 quadraticFunding = (paper.totalPositiveWeight**2) / totalWeight;
            paper.quadraticFunding = quadraticFunding;
        }

        emit QuadraticFundingUpdated(paperId, paper.quadraticFunding);
    }

    function distributeFunds(uint256 paperId) internal {
        Paper storage paper = papers[paperId];
        uint256 totalFunds = paper.quadraticFunding;

        if (totalFunds > 0) {
            uint256 totalWeight = paper.totalPositiveWeight + paper.totalNegativeWeight;

            if (totalWeight > 0) {
                uint256 quadraticFunding = paper.quadraticFunding;

                for (uint256 i = 1; i <= paperCount; i++) {
                    if (i != paperId) {
                        Paper storage otherPaper = papers[i];
                        uint256 otherWeight = otherPaper.totalPositiveWeight + otherPaper.totalNegativeWeight;
                        uint256 funds = (quadraticFunding * (otherWeight**2)) / totalWeight**2;
                        otherPaper.quadraticFunding += funds;
                        totalFunds -= funds;
                    }
                }
            }

            paper.quadraticFunding = totalFunds;
        }
    }

    function positiveVote(uint256 paperId, uint256 weight) public payable {
        Paper storage paper = papers[paperId];
        require(!paper.owners[msg.sender], "Paper owners cannot vote");
        require(paper.stage == PaperStage.Approved, "Paper must be in the Approved stage for voting");
        require(!paper.hasVoted[msg.sender], "Address has already voted on this paper");

        paper.hasVoted[msg.sender] = true;

        uint256 currWeight = paper.totalPositiveWeight;
        if (weight > currWeight) {
            paper.quadraticFunding += (weight - currWeight) * (weight - currWeight);
        }

        paper.totalPositiveWeight = weight;
        calculateQuadraticFunding(paperId);
        distributeFunds(paperId);
    }

    function negativeVote(uint256 paperId, uint256 weight) public payable {
        Paper storage paper = papers[paperId];
        require(!paper.owners[msg.sender], "Paper owners cannot vote");
        require(paper.stage == PaperStage.Rejected, "Paper must be in the Rejected stage for voting");
        require(!paper.hasVoted[msg.sender], "Address has already voted on this paper");
        require(msg.value >= weight * weight, "Insufficient funds to cover the vote cost");

        paper.hasVoted[msg.sender] = true;

        uint256 currWeight = paper.totalNegativeWeight;
        if (weight > currWeight) {
            paper.quadraticFunding += (weight - currWeight) * (weight - currWeight);
        }

        paper.totalNegativeWeight = weight;
        calculateQuadraticFunding(paperId);
        distributeFunds(paperId);
    }
}
