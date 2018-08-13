/**
 * @title P2P CrpytoProtect
 * @author PolicypalNetwork
 * @notice Handles the transactions for P2P CrpytoProtect
 */

pragma solidity 0.4.24;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./ERC20Interface.sol";

contract CrpytoProtect is Ownable {
    using SafeMath for uint256;
    
    ERC20Interface tokenInterface;
    
    // Policy State --
    // 1 - active
    // 2 - inactive
    // 3 - claimed
    struct Policy {
        string name;
        uint256 premiumAmount;
        uint256 payoutAmount;
        uint256 startDate;
        uint256 endDate;
        uint8 state;
    }
    
    struct Token {
        mapping (string => Policy) token;
        string[] tokenRecords;
    }
    
    struct Exchange {
        mapping (string => Token) exchange;
        string[] exchangeRecords;
    }
    
    struct Pool{
        uint256 endDate;
        uint256 amount;
    }
    
    mapping(address => Exchange) policies;
    address[]           private addressRecords;
    
    Pool[]              private poolRecords;
    uint                private poolRecordsIndex;
    uint256             private poolBackedAmount;
    
    // poolState state --
    // 1 - active
    // 2 - not active
    uint8               public poolState;
    uint256             public poolMaxAmount;
    uint256             public poolStartDate;
    
    uint256             public minContribution;
    uint256             public maxContribution;
    
    event PoolStateUpdate(string indexed message);
    event PremiumReceived(address indexed addr, uint256 indexed amount, uint indexed id);
    
    constructor(
        address _tokenContract,
        uint256 _poolMaxAmount,
        uint256 _poolBackedAmount,
        uint256 _minContribution,
        uint256 _maxContribution
    )
        public
    {
        tokenInterface = ERC20Interface(_tokenContract);
        
        poolState = 1;
        poolStartDate = now;
        poolMaxAmount = _poolMaxAmount;
        poolBackedAmount = _poolBackedAmount;
        
        minContribution = _minContribution;
        maxContribution = _maxContribution;
    }
    
    /**
     * @dev Modifier to check pool state
     */
    modifier verifyPoolState(uint256 _premiumAmount) {
        require(poolState == 1);
        require(_premiumAmount >= minContribution);
        require(_premiumAmount <= maxContribution);
        
        // in order to reduce cost
        // require(computePoolAmount() < poolMaxAmount);
        _;
    }
    
    /**
     * @dev Compute Pool Amount
     */
    function computePoolAmount() internal view 
        returns (uint256)
    {
        uint256 currentPoolAmount = 0;
        for (uint i = poolRecordsIndex; i< poolRecords.length; i++) {
            if (poolRecords[i].endDate < now) {
                continue;
            }
            
            currentPoolAmount = currentPoolAmount.add(poolRecords[i].amount);
        }
        
        return currentPoolAmount.add(poolBackedAmount);
    }
    
    /**
     * @dev Make Transaction
     * Make transaction using transferFrom
     */
    function MakeTransaction(
        address _tokenOwner,
        uint256 _premiumAmount,
        uint256 _payoutAmount,
        string _exchange,
        string _token,
        uint8 _id
    ) 
        external
        verifyPoolState(_premiumAmount)
    {
        // check parameters
        require(_tokenOwner != address(this));
        require(_tokenOwner != address(0));
        require(_premiumAmount < _payoutAmount);
        require(bytes(_exchange).length > 0);
        require(bytes(_token).length > 0);
        
        // check eligibility
        require(policies[_tokenOwner].exchange[_exchange].token[_token].state == 0);
        
        // check that token owner address has valid amount
        require(tokenInterface.balanceOf(_tokenOwner) >= _premiumAmount);
        require(tokenInterface.allowance(_tokenOwner, address(this)) >= _premiumAmount);
        
        // record data
        policies[_tokenOwner].exchange[_exchange].token[_token].name = _token;
        policies[_tokenOwner].exchange[_exchange].token[_token].premiumAmount = _premiumAmount;
        policies[_tokenOwner].exchange[_exchange].token[_token].payoutAmount = _payoutAmount;
        policies[_tokenOwner].exchange[_exchange].token[_token].startDate = now;
        policies[_tokenOwner].exchange[_exchange].token[_token].endDate = now.add(90 * 1 days);
        policies[_tokenOwner].exchange[_exchange].token[_token].state = 1;
        
        addressRecords.push(_tokenOwner);
        policies[_tokenOwner].exchangeRecords.push(_exchange);
        policies[_tokenOwner].exchange[_exchange].tokenRecords.push(_exchange);
        
        // record pool
        Pool memory thisPool = Pool(now.add(90 * 1 days), _premiumAmount);
        poolRecords.push(thisPool);
        
        // transfer amount
        tokenInterface.transferFrom(_tokenOwner, address(this), _premiumAmount);
        
        // transfer to owner
        assert(tokenInterface.transfer(owner, _premiumAmount));
        
        emit PremiumReceived(_tokenOwner, _premiumAmount, _id);
    }
    
    /**
     * @dev Get Policy
     */
    function GetPolicy(address _addr, string _exchange, string _token) public view 
        returns (
            string name,
            uint256 premiumAmount,
            uint256 payoutAmount,
            uint256 startDate,
            uint256 endDate,
            uint8 state
        )
    {
        return (
            policies[_addr].exchange[_exchange].token[_token].name,
            policies[_addr].exchange[_exchange].token[_token].premiumAmount,
            policies[_addr].exchange[_exchange].token[_token].payoutAmount,
            policies[_addr].exchange[_exchange].token[_token].startDate,
            policies[_addr].exchange[_exchange].token[_token].endDate,
            policies[_addr].exchange[_exchange].token[_token].state
        );
    }
    
    /**
     * @dev Get Current Pool Amount
     */
    function GetCurrentPoolAmount() public view 
        returns (uint256)
    {
        return computePoolAmount();
    }
    
    /**
     * @dev Update Pool State
     */
    function UpdatePoolState(uint8 _state) external
        onlyOwner
    {
        poolState = _state;
    }
    
    /**
     * @dev Update Backed Amount
     */
    function UpdateBackedAmount(uint256 _amount) external
        onlyOwner
    {
        poolBackedAmount = _amount;
    }
    
    /**
     * @dev Update Contribution Limit
     */
    function UpdateContributionLimit(uint256 _min, uint256 _max) external
        onlyOwner
    {
        require(_min < _max);
        minContribution = _min;
        maxContribution = _max;
    }
    
    /**
     * @dev Emergency Drain
     * in case something went wrong and token is stuck in contract
     */
    function EmergencyDrain(ERC20Interface _anyToken) external
        onlyOwner
        returns(bool)
    {
        if (address(this).balance > 0) {
            owner.transfer(address(this).balance);
        }
        
        if (_anyToken != address(0x0)) {
            assert(_anyToken.transfer(owner, _anyToken.balanceOf(this)));
        }
        return true;
    }
}