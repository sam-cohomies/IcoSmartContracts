// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import {AccessManaged} from "lib/openzeppelin-contracts/contracts/access/manager/AccessManaged.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/// @custom:security-contact sam@cohomies.io
contract ChmIco is AccessManaged, ReentrancyGuard {
    error ZeroAddressNotAllowed();
    error InvalidState();
    error InsufficientPayment();
    error UnsupportedCurrency();

    enum IcoState {
        Stage1,
        Stage2,
        Stage3,
        Stage4,
        Stage5,
        Stage6,
        Stage7,
        Stage8,
        Stage9,
        Stage10,
        Stage11,
        NotStarted,
        Succeeded,
        Failed
    }

    enum Currency {
        USDT,
        USDC,
        ETH
    }

    struct Stage {
        uint256 tokensAvailable; // Total tokens available for sale (no decimals)
        uint256 tokensSold; // Total tokens sold (no decimals)
        uint256 price; // Price of one token in microUSDT (6 decimals)
        uint256 duration; // Duration of the stage using solidity default encoding
    }

    struct User {
        uint256 usdtSpent; // Total USDT measured in microUSDT spent by the user (6 decimals)
        uint256 usdcSpent; // Total USDC measured in wei-like units spent by the user (18 decimals)
        uint256 ethSpent; // Total ETH measured in wei spent by the user (18 decimals)
        uint256 chmBought; // Total CHM bought by the user (no decimals)
    }

    Stage[] private stages;

    mapping(address => User) private userData;

    IcoState private icoState;

    uint256 public constant MINIMUM_RAISE = 1_000_000; // 1 million USDT
    uint256 private raisedAmount; // Total amount raised in microUSDT (6 decimals)

    constructor(address _accessControlManager) AccessManaged(_accessControlManager) {
        // TODO: Decide how long stages should last
        // TODO: Do some modelling to decide on stage details
        stages.push(Stage(25_000_000, 0, 3_500, 1 days));
        stages.push(Stage(35_000_000, 0, 3_900, 1 days));
        stages.push(Stage(50_000_000, 0, 4_400, 1 days));
        stages.push(Stage(65_000_000, 0, 4_900, 1 days));
        stages.push(Stage(80_000_000, 0, 5_500, 1 days));
        stages.push(Stage(95_000_000, 0, 6_200, 1 days));
        stages.push(Stage(110_000_000, 0, 6_900, 1 days));
        stages.push(Stage(115_000_000, 0, 7_700, 1 days));
        stages.push(Stage(130_000_000, 0, 8_500, 1 days));
        stages.push(Stage(145_000_000, 0, 9_400, 1 days));
        stages.push(Stage(150_000_000, 0, 10_400, 1 days));
    }

    function purchaseTokens(Currency currency, uint256 amount, IcoState expectedState, uint256 expectedTokens)
        external
        nonReentrant
    {
        if (icoState != expectedState) {
            revert InvalidState();
        }
        // Additional purchase logic
        Stage storage currentStage = stages[uint256(icoState)];
        uint256 cost;
        if (currency == Currency.USDT) {
            cost = amount * currentStage.price;
        } else if (currency == Currency.USDC) {
            cost = amount * currentStage.price * 1e12;
        } else if (currency == Currency.ETH) {
            cost = amount;
        } else {
            revert UnsupportedCurrency();
        }
        uint256 tokensToAllocate = cost / currentStage.price;
        if (tokensToAllocate != expectedTokens) {
            revert InvalidState();
        }
        // Finalize purchase
    }

    function progressStage() external nonReentrant restricted {
        // Additional stage progress logic
        if (icoState == IcoState.Stage11) {
            // Finalize ICO
            icoState = IcoState.Succeeded; // TODO: Implement finalization logic
        }
        // Finalize stage progress
    }

    function refund() external nonReentrant {
        if (icoState != IcoState.Failed) {
            revert InvalidState();
        }
        // Additional refund logic
        // Finalize refund
    }
}
