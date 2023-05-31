// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RQ {
    enum PaperStage { Approved, Rejected, Published }

    struct Paper {
        string title;
        string author;
        string content;
        uint256 timestamp;
        uint256 funding;
        bool isReproducible;
        address payable owner;
        PaperStage stage;
        // more than 1 owners for a paper
        mapping(address => bool) owners;
        address walletAddress;
        // quad voting
        mapping(address => uint) positiveVotes; // user => weight
        mapping(address => uint) negativeVotes; // user => weight
        uint totalPositiveWeight;
        uint totalNegativeWeight;
    }

    mapping(uint256 => Paper) public papers;
    uint256 public paperCount;
    // cost of voting
    uint constant public voteCost = 1;
    mapping(address => bool) public members;

    event PaperUploaded(uint256 indexed paperId, string title, string author, uint256 timestamp, PaperStage stage);
    event PaperStageUpdated(uint256 indexed paperId, PaperStage stage);
    event FundingUpdated(uint256 indexed paperId, uint256 funding);
    event Voted(uint paperId, uint weight, bool positive);
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
        newPaper.owner = payable(msg.sender);
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

    // helper functions
  function currentWeight(uint paperId, address addr, bool isPositive) public view returns(uint) {
    if (isPositive) {
      return papers[paperId].positiveVotes[addr];
    } else {
      return papers[paperId].negativeVotes[addr];
    }
  }

  function calcCost(uint currWeight, uint weight) public pure returns(uint) {
    if (currWeight > weight) {
      return weight * weight * voteCost; // cost is always quadratic
    } else if (currWeight < weight) {
      // this allows users to save on costs if they are increasing their vote
      // example: current weight is 3, they want to change it to 5
      // this would cost 16x (5 * 5 - 3 * 3) instead of 25x the vote cost
      return (weight * weight - currWeight * currWeight) * voteCost;
    } else {
      return 0;
    }
  }
// helper fubnc end

    function positiveVote(uint paperId, uint weight) public payable {
    Paper storage paper = papers[paperId];
    require(msg.sender != paper.owner); // owners cannot vote on their own papers

    uint currWeight = paper.positiveVotes[msg.sender];
    if (currWeight == weight) {
      return; // no need to process further if vote has not changed
    }

    uint cost = calcCost(currWeight, weight);
    require(msg.value >= cost); // msg.value must be enough to cover the cost

    paper.positiveVotes[msg.sender] = weight;
    paper.totalPositiveWeight += weight - currWeight;

    // weight cannot be both positive and negative simultaneously
    paper.totalNegativeWeight -= paper.negativeVotes[msg.sender];
    paper.negativeVotes[msg.sender] = 0;

    paper.funding += msg.value; // reward creator of paper for their contribution

    emit Voted(paperId, weight, true);
  }

  function negativeVote(uint paperId, uint weight) public payable {
    Paper storage paper = papers[paperId];
    require(msg.sender != paper.owner);

    uint currWeight = paper.negativeVotes[msg.sender];
    if (currWeight == weight) {
      return; // no need to process further if vote has not changed
    }

    uint cost = calcCost(currWeight, weight);
    require(msg.value >= cost); // msg.value must be enough to cover the cost

    paper.negativeVotes[msg.sender] = weight;
    paper.totalNegativeWeight += weight - currWeight;

    // weight cannot be both positive and negative simultaneously
    paper.totalPositiveWeight -= paper.positiveVotes[msg.sender];
    paper.positiveVotes[msg.sender] = 0;

    // distribute voting cost to every paper except for this one
    uint reward = msg.value / (paperCount - 1);
    for (uint i = 0; i < paperCount; i++) {
      if (i != paperId) papers[i].funding += reward;
    }

    emit Voted(paperId, weight, false);
  }

    function claim(uint paperId) public {
        Paper storage paper = papers[paperId];
        require(msg.sender == paper.owner);
        paper.owner.transfer(paper.funding);
        paper.funding = 0;
    }
    
}
