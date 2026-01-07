// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockETH
 * @dev Mock ETH token for testing on testnets. Only deployer (owner) can mint.
 */
contract MockETH is ERC20, Ownable {
    constructor() ERC20("Mock ETH", "mETH") Ownable(msg.sender) {}

    /**
     * @dev Mints tokens to a specified address. Only owner can mint.
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Cannot mint to zero address");
        _mint(to, amount);
    }

    /**
     * @dev Burns tokens from the caller's balance
     * @param amount The amount of tokens to burn
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /**
     * @dev Returns the number of decimals used for token amounts
     * @return uint8 The number of decimals (18 for ETH-like tokens)
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }
}



