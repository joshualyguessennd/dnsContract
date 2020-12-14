pragma solidity >=0.4.22 <0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Destructible is Ownable {
    function destroy() public onlyOwner {
        selfdestruct(owner);
    }

    function destroyandSend(address _recipient) public onlyOwner {
        selfdestruct(_recipient);
    }
}