//SPDX-Lincense-Identifier: MIT
pragma solidity ^0.8.30;


contract MyFaucet{
    address faucetOwner;
    mapping(address => uint256) public balanceOf;

    uint256 public totalSupply;
    uint256 public constant WITHDRAWAL_AMOUNT = 100 * 10**18; // 10 CFT
    uint256 public constant COOLDOWN_PERIOD = 1 days;
    mapping (address => uint256) public lastWithdrawalTime;

    string tokenName;
    string tokenSymbol;
    uint8 public tokenDecimal = 18;

    // EVENTS

    event Minted(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    modifier onlyFaucetOwner {
        require(faucetOwner == msg.sender, "not faucet owner!");
        _;
    }


    constructor(string memory _tokenName, string memory _tokenSymbol) {
        faucetOwner = msg.sender;
        tokenName = _tokenName;
        tokenSymbol = _tokenSymbol;
    }

    function mintTokensToFaucet(uint256 amount) external onlyFaucetOwner  { // mint 1b tokens initially
        //checks
        require(amount > 0, "cannot mint zero amount of token");

        //effects
        balanceOf[address(this)] += amount;
        totalSupply += amount;

        //interactions

        emit Minted(address(this), amount);

    }

    function withdrawTokenFromFaucet(address user) public {
        // checks
        require(block.timestamp >= lastWithdrawalTime[msg.sender] + COOLDOWN_PERIOD, "cannot withdraw twice within 24 hours");
        require(balanceOf[address(this)] > WITHDRAWAL_AMOUNT, "Insufficient token in faucet");

        //effects/interactions

        lastWithdrawalTime[msg.sender] = block.timestamp;
        balanceOf[address(this)] -= WITHDRAWAL_AMOUNT;
        balanceOf[address(user)] += WITHDRAWAL_AMOUNT;

        emit Withdrawn(msg.sender, WITHDRAWAL_AMOUNT);
        
    }


    function getFaucetOwner() public view returns (address) {
        return address(faucetOwner);
    }



}







