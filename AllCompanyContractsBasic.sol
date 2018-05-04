pragma solidity ^0.4.20;

library SafeMath {

	function mul(uint256 a, uint256 b) internal pure returns (uint256) {
		if (a == 0) {
			return 0;
		}
		uint256 c = a * b;
		assert(c / a == b);
		return c;
	}

	function div(uint256 a, uint256 b) internal pure returns (uint256) {
		// assert(b > 0); // Solidity automatically throws when dividing by 0
		uint256 c = a / b;
		// assert(a == b * c + a % b); // There is no case in which this doesn't hold
		return c;
	}

	function sub(uint256 a, uint256 b) internal pure returns (uint256) {
		assert(b <= a);
		return a - b;
	}

	function add(uint256 a, uint256 b) internal pure returns (uint256) {
		uint256 c = a + b;
		assert(c >= a);
		return c;
	}
}

contract ERC20 {
  function totalSupply() public view returns (uint256);
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  function allowance(address owner, address spender) public view returns (uint256);
  function burnFrom(address from,  uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  
  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract ICompanyToken is ERC20 {
	function mint(address _to, uint256 _amount) public returns(bool);
	function burn(address _who, uint256 _amount) public returns(bool);
	function activate() public returns(bool);
	function companyClose() public;
	event Activate(address indexed _who, bool functional);
	event Mint(address indexed minter, uint256 value);
	event Burn(address indexed burner, uint256 value);
}

contract IBasicCompany {
	function activateCompany() public payable returns(bool);
	function increaseCapital() public payable returns(bool);
	function payTo(address who, uint256 weiAmount) public returns(bool);
	function payToCompany(uint256 _amountInWei) public;
	function closeCompany() public;
	
	event ActivateCompany(address indexed who, uint256 amount);
	event IncreaseCapital(address indexed who, uint256 amount);
	event DecreaseCapital(address indexed who, uint256 amount);
	event CloseCompany(address indexed who);
}

contract ICompanyExchanger {
    function capitalDeposit() public payable returns(uint256 tokens);
	function _withdraw(uint256 weiAmount) public returns(uint256);
	function tokenPriceCalculator() internal;
	function getTokenPrice() public view returns(uint256);
	function getCompanyShares() public view returns(uint256);
	function getCompanyBalance() public view returns(uint256);
	function closeIt() public;
}

contract BasicCompany is IBasicCompany {
    using SafeMath for uint256;
    
	address public thisCompanyExchanger;
	address public thisCompanyToken;
		
	string public companyName;

	modifier onlyOwners {
		require(ICompanyToken(thisCompanyToken).balanceOf(msg.sender) > 0);
		_;
	}

	constructor(string _companyName, string _companySymbol) public {
		companyName = _companyName;
		thisCompanyToken = new CompanyToken(_companyName, _companySymbol);
		thisCompanyExchanger = new CompanyExchanger(thisCompanyToken);
	}
	
	function() public payable {

	}
	
	/*function activateCompany() public payable onlyOwners returns(bool){ //todo modifier
		require(msg.value == ICompanyToken(thisCompanyToken).totalSupply());
		thisCompanyExchanger.transfer(msg.value);
		ICompanyToken(thisCompanyToken).transfer(msg.sender, ICompanyToken(thisCompanyToken).totalSupply());
		
		emit ActivateCompany(msg.sender, msg.value);
		
		return ICompanyToken(thisCompanyToken).activate();
	}*/
	
	function increaseCapital() public payable onlyOwners returns(bool) {
		require(msg.value > 0); 
		uint256 tokens = ICompanyExchanger(thisCompanyExchanger).capitalDeposit.value(msg.value)();
		
		emit IncreaseCapital(msg.sender, msg.value);
		
		return ICompanyToken(thisCompanyToken).mint(msg.sender, tokens);
	}
	
	function payFromCompanyTo(address to, uint256 weiAmount) public onlyOwners returns(bool) {
		uint256 tokens = ICompanyExchanger(thisCompanyExchanger)._withdraw(weiAmount);
		ICompanyToken(thisCompanyToken).burn(msg.sender, tokens);
		to.transfer(weiAmount);
		emit DecreaseCapital(msg.sender, tokens);
	}
	
	function payFromOwnerNameTo(address _fromNameOf, address to, uint256 weiAmount) public returns(bool) {
	    require(ICompanyToken(thisCompanyToken).allowance(_fromNameOf ,msg.sender) > 0);
		uint256 tokens = ICompanyExchanger(thisCompanyExchanger)._withdraw(weiAmount);
		ICompanyToken(thisCompanyToken).burnFrom(_fromNameOf, msg.sender, tokens);
		to.transfer(weiAmount);
		emit DecreaseCapital(msg.sender, tokens);
	}
	
	function closeCompany() public onlyOwners {
		ICompanyExchanger(thisCompanyExchanger).closeIt();
		emit CloseCompany(msg.sender);
	}
}

contract CompanyToken is ICompanyToken {
	using SafeMath for uint256;
	
	/* Public variables of the token */
	string public name;
	string public symbol;
	
	uint256 public decimals;
	
	uint256 public _totalSupply;
	
	address public basicCompanyController;
		
	/* This creates an array with all balances */
	mapping (address => uint256) public balances;
    mapping (address => mapping (address => uint256)) internal allowed;
		
	modifier onlyPayloadSize(uint256 numwords) {                                         
		assert(msg.data.length == numwords * 32 + 4);
		_;
	}
	
	modifier onlyController {
		require(msg.sender == basicCompanyController);
		_;
	}
	
	modifier isFunctional {
		require(functional == true);
		_;
	}

	/* Initializes contract with initial supply tokens to the creator of the contract */
	constructor(string _tokenName, string _tokenSymbol) public {
		basicCompanyController = msg.sender;
		name = _tokenName;                                   	// Set the name for display purposes
		symbol = _tokenSymbol;                               				// Set the symbol for display purposes
		decimals = 18;                            					// Amount of decimals for display purposes
		_totalSupply = 1;
		balances[msg.sender] = _totalSupply;
		functional = true;
	}
	
	function() payable public {
		revert();
	}
	
	/*function activate() public onlyController returns(bool) {
		require(functional == false);
		functional = true;
		
		emit Activate(msg.sender, functional); 
		
		return functional;
	}*/

	function transfer(address _to, uint256 _value) onlyPayloadSize(2) public returns (bool _success) {
		return _transfer(msg.sender, _to, _value);
	}
	
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_value <= allowed[_from][msg.sender]);     // Check allowance
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        _transfer(_from, _to, _value);
        return true;
    }
	
	/* Internal transfer, only can be called by this contract */
	function _transfer(address _from, address _to, uint256 _value) internal returns (bool _success) {
		require (_to != address(0x0));														// Prevent transfer to 0x0 address.
		require(_value > 0);
		require (balances[_from] >= _value);                								// Check if the sender has enough
		require (balances[_to].add(_value) > balances[_to]); 								// Check for overflows
		
		uint256 previousBalances = balances[_from].add(balances[_to]);						// Save this for an assertion in the future
		
		balances[_from] = balances[_from].sub(_value);        				   				// Subtract from the sender
		balances[_to] = balances[_to].add(_value);                            				// Add the same to the recipient
		
		emit Transfer(_from, _to, _value);
		
		// Asserts are used to use static analysis to find bugs in your code. They should never fail
        assert(balances[_from].add(balances[_to]) == previousBalances);
		
		return true;
	}

	function increaseApproval(address _spender, uint256 _addedValue) onlyPayloadSize(2) public returns (bool _success) {
		require(allowed[msg.sender][_spender].add(_addedValue) <= balances[msg.sender]);
		
		allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
		
		emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
		
		return true;
	}

	function decreaseApproval(address _spender, uint256 _subtractedValue) onlyPayloadSize(2) public returns (bool _success) {
		uint256 oldValue = allowed[msg.sender][_spender];
		
		if (_subtractedValue > oldValue) {
			allowed[msg.sender][_spender] = 0;
		} else {
			allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
		}
		
		emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
		
		return true;
	}
	
	function approve(address _spender, uint256 _value) onlyPayloadSize(2) public returns (bool _success) {
		require(_value <= balances[msg.sender]);
		
		allowed[msg.sender][_spender] = _value;
		
		emit Approval(msg.sender, _spender, _value);
		
		return true;
	}
	
	function mint(address _to, uint256 _amount) public onlyController returns (bool) {
		_totalSupply = _totalSupply.add(_amount);
		balances[_to] = balances[_to].add(_amount);
		
		emit Mint(_to, _amount);
		
		return true;
	}	
  
	function burn(address _who, uint256 _amount) public onlyController returns (bool) {
		require(_amount <= balances[_who]);
		require(_totalSupply >= _amount);
		balances[_who] = balances[_who].sub(_amount);
		_totalSupply = _totalSupply.sub(_amount);
		require(_totalSupply > 0);
		emit Burn(_who, _amount);
		emit Transfer(_who, address(0), _amount);
		
		return true;
	}
	
    function burnFrom(address _from, address who, uint256 _value) public onlyController returns (bool success) {
        require(balances[_from] >= _value);                // Check if the targeted balance is enough
        require(_value <= allowed[_from][who]);    // Check allowance
        balances[_from] = balances[_from].sub(_value);                         // Subtract from the targeted balance
        allowed[_from][who] = allowed[_from][who].sub(_value);             // Subtract from the sender's allowance
        _totalSupply = _totalSupply.sub(_value);                              // Update totalSupply
		require(_totalSupply > 0);
		emit Transfer(_from, address(0), _value);
        emit Burn(_from, _value);
        return true;
    }
	
	function companyClose() public onlyController {
		selfdestruct(msg.sender);
	}
  
	function totalSupply() public view returns (uint256) {
		return _totalSupply;
	}
	
	function balanceOf(address _owner) public view returns (uint256 balance) {
		return balances[_owner];
	}
	
	function allowance(address _owner, address _spender) public view returns (uint256 _remaining) {
		return allowed[_owner][_spender];
	}
}

//Accountant
contract CompanyExchanger is ICompanyExchanger {
	using SafeMath for uint256;
	
	address public basicCompanyController;
	address public thisExchangerToken;
	
	uint256 public tokenPrice;
	
	modifier onlyController {
		require(msg.sender == basicCompanyController);
		_;
	}

	constructor(address _token) public {
		basicCompanyController = msg.sender;
		thisExchangerToken = _token;
		tokenPriceCalculator();
	}

	function() public payable {
		tokenPriceCalculator();
	}
	
	function capitalDeposit() public payable onlyController returns (uint256 tokens) {
		require(msg.value > 0);
		tokens = msg.value.div(tokenPrice);
		tokenPriceCalculator();
		return tokens;
	}
	
	function _withdraw(uint256 _weiAmount) public onlyController returns (uint256 tokensAmount) {
		tokensAmount = _weiAmount.div(tokenPrice);
		basicCompanyController.transfer(tokensAmount);
		tokenPriceCalculator();
		return tokensAmount;
	}
	
	function closeIt() public onlyController {
		basicCompanyController.transfer(address(this).balance);
		selfdestruct(msg.sender);
	}
	
	function tokenPriceCalculator() internal {
		tokenPrice = address(this).balance.div(ERC20(thisExchangerToken).totalSupply());
	}
	
	function getTokenPrice() public view returns(uint256) {
		return tokenPrice;
	}
	
	function getCompanyShares() public view returns(uint256) {
		return ERC20(thisExchangerToken).totalSupply();
	}
	
	function getCompanyBalance() public view returns(uint256) {
		return address(this).balance;
	}
}

contract Register {
	//TODO
}
