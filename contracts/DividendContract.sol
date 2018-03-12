pragma solidity ^0.4.17;

// ----------------------------------------------------------------------------
// Safe maths
// ----------------------------------------------------------------------------
library SafeMath {
    function add(uint a, uint b) internal pure returns (uint c) {
        assert((c = a + b) >= a);
    }
    
    function sub(uint a, uint b) internal pure returns (uint c) {
        assert((c = a - b) <= a);
    }
    
    function mul(uint a, uint b) internal pure returns (uint c) {
        assert((c = a * b) >= a);
    }
    
    function div(uint a, uint b) internal pure returns (uint c) {
        assert(b > 0);
        assert((c = a / b) <= a);
    }
}

// ----------------------------------------------------------------------------
// ERC Token Standard #20 Interface
// https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md
// ----------------------------------------------------------------------------
contract ERC20Interface {
    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

contract DSAuthEvents {
    event LogSetOwner     (address indexed owner);
}

contract DSAuth is DSAuthEvents {
    // DSAuthority  public  authority;
    address      public  owner;

    function DSAuth() public {
        owner = msg.sender;
        LogSetOwner(msg.sender);
    }
    
    function setOwner(address owner_) public isOwner {
        assert(owner_ != address(0));
        
        owner = owner_;
        LogSetOwner(owner);
    }

    modifier isOwner {
        assert(checkIsOwner(msg.sender));
        _;
    }

    function checkIsOwner(address src) internal view returns (bool) {
        return src == owner;
    }
}

contract RestrictedToken is ERC20Interface, DSAuth {
    using SafeMath for uint;
    
    string public  name;
    string public symbol;
    uint8 public decimals;
    uint initalSupply;
    address public viewer;
    
    mapping (address => uint) public balances;
    
    function RestrictedToken(string _name, string _symbol, uint8 _decimals, uint _initalSupply, address _viewer) public {
        assert(_initalSupply != 0);
        assert(_viewer != address(0));
        
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        viewer = _viewer;
        
        initalSupply = initalSupply.add(_initalSupply) * 10 ** uint256(decimals);
        balances[viewer] = initalSupply;
    }
    
    function totalSupply() public view returns (uint) {
        return initalSupply;
    }

    function balanceOf(address src) public view returns (uint balance) {
        return balances[src];
    }

    function transfer(address to, uint tokens) public isOwner returns (bool) {
        return _transfer(viewer, to, tokens);
    }
    
    function _transfer(address from, address to, uint tokens) internal returns (bool) {
        balances[from] = balances[from].sub(tokens);
        balances[to] = balances[to].add(tokens);
        Transfer(from, to, tokens);
        
        return true;
    }

    function recycle(address from, uint tokens) public isOwner returns (bool success) {
        uint recycling = tokens;
        
        if (recycling > balances[from]) {
            recycling = balances[from];
        }
        
        return _transfer(from, viewer, recycling);
    }

    function () public payable {
        revert();
    }

    function approve(address spender, uint tokens) public returns (bool success) {
        revert();
    }

    function allowance(address tokenOwner, address spender) public constant returns (uint remaining) {
        revert();
    }

    function transferFrom(address from, address to, uint tokens) public returns (bool success) {
        revert();
    }

    function approveAndCall(address spender, uint tokens, bytes data) public returns (bool success) {
        revert();
    }
}

contract DividendContract is DSAuth {
    using SafeMath for uint;
    
    RestrictedToken public myToken;
    uint public assignableSupply;
    uint public assignedAmount;
    uint public rangeInDay;
    
    struct Reward {
        uint val;
        uint deadline;
    }
    
    struct Employee {
        bool isValid;
        uint totalReward;
        Reward[] rewards;
    }
    
    mapping (address => Employee) public employees;
    
    function DividendContract(string _name, string _symbol, uint8 _decimals, uint _initalSupply, uint _rangeInDay) public {
        assert(_initalSupply != 0);
        assert(_rangeInDay != 0);
        
        rangeInDay = _rangeInDay * 1 days;
        myToken = new RestrictedToken(_name, _symbol, _decimals, _initalSupply, msg.sender);
        
        assignableSupply = _initalSupply;
        assignedAmount = 0;
    }
    
    event AddEmplyee(address src);
    event RemoveEmplyee(address src, uint recycling);
    event RewardEmployee(address src, uint amount);
    event RecycleReward(address src, uint recycling);
    
    function addEmplyee(address src) public isOwner {
        assert(src != address(0));
        assert(!employees[src].isValid);
        
        Employee storage employee = employees[src];
        employee.isValid = true;
        employee.totalReward = 0;
        delete employee.rewards;
        
        assert(employee.isValid);
        assert(employee.totalReward == 0);
        assert(employee.rewards.length == 0);
        
        AddEmplyee(src);
    }
    
    function removeEmplyee(address src) public isOwner {
        assert(src != address(0));
        assert(employees[src].isValid);
        
        Employee storage employee = employees[src];
        uint amount = employee.totalReward;
        
        if (amount > 0) {
            myToken.recycle(src, amount);
            assignedAmount = assignedAmount.sub(amount);
        }
        
        employee.isValid = false;
        employee.totalReward = 0;
        delete employee.rewards;
        
        assert(!employee.isValid);
        assert(employee.totalReward == 0);
        assert(employee.rewards.length == 0);
        
        delete employees[src];
        
        RemoveEmplyee(src, amount);
    }
    
    function rewardEmployee(address src, uint amount) public isOwner {
        assert(assignableSupply >= assignedAmount.add(amount));
        assert(src != address(0));
        assert(employees[src].isValid);
        
        myToken.transfer(src, amount);
        assignedAmount = assignedAmount.add(amount);
        
        Employee storage employee = employees[src];
        employee.totalReward = employee.totalReward.add(amount);
        employee.rewards.push(Reward({
           val: amount, deadline: calDeadline() 
        }));
        
        RewardEmployee(src, amount);
    }
    
    function calDeadline() internal view returns (uint) {
        return now.add(rangeInDay);
    }
    
    function rewardEmployees(address[] addresses, uint[] amounts) public isOwner {
        require(addresses.length == amounts.length);
        
        uint len = addresses.length;
        
        for (uint i = 0; i < len; ++i) {
            rewardEmployee(addresses[i], amounts[i]);
        }
    }
    
    function recycleRewardFromEmployees(address[] addresses) public isOwner {
        uint len = addresses.length;
        
        for (uint i = 0; i < len; ++i) {
            recycleRewardFromEmployee(addresses[i]);
        }
    }
    
    function recycleRewardFromEmployee(address src) public isOwner {
        assert(src != address(0));
        assert(employees[src].isValid);
        
        Employee storage employee = employees[src];
        
        uint recycling = 0;
        
        Reward[] storage rewards = employee.rewards;
        uint len = rewards.length;
        uint count = 0;
        
        for (uint i = 0; i < len; ++i) {
            if (now > rewards[i].deadline) {
                recycling = recycling.add(rewards[i].val);
                myToken.recycle(src, rewards[i].val);
                
                ++count;
            }
        }
        
        if (count == 0) {
            return;
        }
        
        if (count == len) {
            delete employee.rewards;
        } else {
            Reward[] memory tmp = new Reward[](len.sub(count));
            
            for (i = 0; i < tmp.length; ++i) {
                tmp[i] = rewards[i + count];
            }
            
            delete employee.rewards;
            
            for (i = 0; i < tmp.length; ++i) {
                employee.rewards.push(tmp[i]);
            }
        }
        
        assignedAmount = assignedAmount.sub(recycling);
        RecycleReward(src, recycling);
    }
}
