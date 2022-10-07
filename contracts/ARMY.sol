//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./Game.sol";

contract ARMYToken is ERC20, Ownable {
	address gameContract;

	function mint(address _to, uint256 _amount) external {
		require(_msgSender() == gameContract, "Only Game Contract can mint tokens");
		_mint(_to, _amount);
	}

	function burn(address _from, uint256 _amount) external {
		require(_msgSender() == gameContract, "Only Game Contract can burn tokens");
		_burn(_from, _amount);
	}

	function selfBurn(uint256 _amount) public {
		_burn(_msgSender(), _amount);
	}

	function decimals() public view virtual override returns(uint8) {
		return 12;
	}

	// Admin functions
	function setGameContract(address _contractAddress) public onlyOwner {
		gameContract = _contractAddress;
	}

	constructor() ERC20 ("ARMYToken", "ARMY") {
		_mint(_msgSender(), 1000 * 10 ** decimals());
	}
}