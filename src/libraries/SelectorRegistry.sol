// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SelectorRegistry
 * @notice Registry untuk mengelola function selectors dengan berbagai pendekatan
 */
library SelectorRegistry {
    
    // Pendekatan 1: Enum-based selector management
    enum ProtocolType {
        UNISWAP_V3,
        UNISWAP_V2,
        ERC20,
        CUSTOM
    }
    
    // Pendekatan 2: Struct untuk grouped selectors
    struct SelectorGroup {
        string name;
        bytes4[] selectors;
        bool isActive;
    }
    
    /**
     * @notice Get selectors berdasarkan protokol
     * @param protocolType Jenis protokol
     * @return selectors Array of function selectors
     */
    function getProtocolSelectors(ProtocolType protocolType) 
        internal 
        pure 
        returns (bytes4[] memory selectors) 
    {
        if (protocolType == ProtocolType.UNISWAP_V3) {
            selectors = new bytes4[](4);
            selectors[0] = ISwapRouter.exactInputSingle.selector;
            selectors[1] = ISwapRouter.exactOutputSingle.selector;
            selectors[2] = ISwapRouter.exactInput.selector;
            selectors[3] = ISwapRouter.exactOutput.selector;
        } else if (protocolType == ProtocolType.UNISWAP_V2) {
            selectors = new bytes4[](2);
            selectors[0] = bytes4(keccak256("swapExactTokensForTokens(uint256,uint256,address[],address,uint256)"));
            selectors[1] = bytes4(keccak256("swapTokensForExactTokens(uint256,uint256,address[],address,uint256)"));
        } else if (protocolType == ProtocolType.ERC20) {
            selectors = new bytes4[](4);
            selectors[0] = IERC20.transfer.selector;
            selectors[1] = IERC20.approve.selector;
            selectors[2] = IERC20.transferFrom.selector;
            selectors[3] = bytes4(keccak256("balanceOf(address)"));
        }
        
        return selectors;
    }
    
    /**
     * @notice Get selector dengan verifikasi
     * @param signature Function signature string
     * @return selector Calculated selector
     */
    function calculateSelector(string memory signature) 
        internal 
        pure 
        returns (bytes4 selector) 
    {
        return bytes4(keccak256(bytes(signature)));
    }
    
    /**
     * @notice Verify jika selector matches dengan signature
     * @param selector Selector to verify
     * @param signature Expected function signature
     * @return isValid True if matches
     */
    function verifySelector(bytes4 selector, string memory signature) 
        internal 
        pure 
        returns (bool isValid) 
    {
        return selector == bytes4(keccak256(bytes(signature)));
    }
    
    /**
     * @notice Get all Uniswap selectors dengan dokumentasi
     * @return uniV3Selectors Array of Uniswap V3 selectors
     * @return uniV2Selectors Array of Uniswap V2 selectors
     * @return descriptions Array of descriptions
     */
    function getAllUniswapSelectors() 
        internal 
        pure 
        returns (
            bytes4[] memory uniV3Selectors,
            bytes4[] memory uniV2Selectors,
            string[] memory descriptions
        ) 
    {
        // Uniswap V3
        uniV3Selectors = new bytes4[](4);
        uniV3Selectors[0] = ISwapRouter.exactInputSingle.selector;
        uniV3Selectors[1] = ISwapRouter.exactOutputSingle.selector;
        uniV3Selectors[2] = ISwapRouter.exactInput.selector;
        uniV3Selectors[3] = ISwapRouter.exactOutput.selector;
        
        // Uniswap V2 style
        uniV2Selectors = new bytes4[](2);
        uniV2Selectors[0] = bytes4(keccak256("swapExactTokensForTokens(uint256,uint256,address[],address,uint256)"));
        uniV2Selectors[1] = bytes4(keccak256("swapTokensForExactTokens(uint256,uint256,address[],address,uint256)"));
        
        // Descriptions
        descriptions = new string[](6);
        descriptions[0] = "exactInputSingle - Single pool exact input swap";
        descriptions[1] = "exactOutputSingle - Single pool exact output swap";
        descriptions[2] = "exactInput - Multi-hop exact input swap";
        descriptions[3] = "exactOutput - Multi-hop exact output swap";
        descriptions[4] = "swapExactTokensForTokens - V2 style exact input";
        descriptions[5] = "swapTokensForExactTokens - V2 style exact output";
        
        return (uniV3Selectors, uniV2Selectors, descriptions);
    }
}
