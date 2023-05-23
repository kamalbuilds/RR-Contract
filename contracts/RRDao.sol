// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RRDao {
    enum PaperStage { Approved, Rejected, Published }

    struct Paper {
        string title;
        string author;
        string content;
        uint256 timestamp;
        uint256 funding;
        bool isReproducible;
        PaperStage stage;
        mapping(address => bool) owners;
        address walletAddress;
    }

    mapping(uint256 => Paper) public papers;
    uint256 public paperCount;

    mapping(address => bool) public members;

    event PaperUploaded(uint256 indexed paperId, string title, string author, uint256 timestamp, PaperStage stage);
    event PaperStageUpdated(uint256 indexed paperId, PaperStage stage);
    event FundingUpdated(uint256 indexed paperId, uint256 funding);

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

    function uploadPaper(string memory title, string memory author, string memory content, uint256 funding, bool isReproducible, PaperStage stage , address walletAddress) external {
        uint256 timestamp = block.timestamp;
        uint256 paperId = paperCount + 1;

        Paper storage newPaper = papers[paperId];
        newPaper.title = title;
        newPaper.author = author;
        newPaper.content = content;
        newPaper.timestamp = timestamp;
        newPaper.funding = funding;
        newPaper.isReproducible = isReproducible;
        newPaper.stage = stage;
        newPaper.walletAddress = walletAddress;
        papers[paperId].owners[msg.sender] = true;
        paperCount++;

        emit PaperUploaded(paperId, title, author, timestamp, stage);
    }

    function updatePaperStage(uint256 paperId, PaperStage stage) public onlyMembers {
        require(paperId <= paperCount, "Invalid paperId");
        papers[paperId].stage = stage;

        emit PaperStageUpdated(paperId, stage);
    }

    function updateFunding(uint256 paperId, uint256 newFunding) external {
        require(paperId <= paperCount, "Invalid paperId");
        require(papers[paperId].owners[msg.sender], "You can only update funding for your own paper");

        papers[paperId].funding = newFunding;

        emit FundingUpdated(paperId, newFunding);
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
    
}
