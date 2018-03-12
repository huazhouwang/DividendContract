pragma solidity ^0.4.17;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/DividendContract.sol";

contract TestDividend {
    DividendContract dividend = DividendContract(DeployedAddresses.DividendContract());
    RestrictedToken token = RestrictedToken(dividend.myToken());

    function testTokenBasic() public {
        assert(token.decimals() == 18);
        assert(token.totalSupply() == 10000000000000000000000);
    }
    
    function testTokenOwner() public {
        assert(token.owner() == address(dividend));
    }
}
