// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "./libraries/BoringAddress.sol";
import "./libraries/BoringMath.sol";
import "./interfaces/IERC1155.sol";
import "./interfaces/IERC1155TokenReceiver.sol";

abstract contract ERC1155 is IERC1155 {
    using BoringAddress for address;
    using BoringMath for uint256;

    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);

    // mappings
    mapping(address => mapping(address => bool)) public override isApprovedForAll; // map of operator approval
    mapping(address => mapping(uint256 => uint256)) public override balanceOf; // map of tokens owned by

    function supportsInterface(bytes4 interfaceID) public view override returns (bool) {
        return
            interfaceID == this.supportsInterface.selector || // EIP-165
            interfaceID == 0xd9b67a26; // ERC-1155
    }

    function balanceOfBatch(address[] calldata owners, uint256[] calldata ids)
        external
        view
        override
        returns (uint256[] memory balances)
    {
        uint256 len = owners.length;
        require(len == ids.length, "ERC1155: Length mismatch");

        balances = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            balances[i] = balanceOf[owners[i]][ids[i]];
        }
    }

    function _mint(
        address to,
        uint256 id,
        uint256 value
    ) internal {
        require(to != address(0), "No 0 address");

        balanceOf[to][id] = balanceOf[to][id].add(value);

        emit TransferSingle(msg.sender, address(0), to, id, value);
    }

    function _burn(
        address from,
        uint256 id,
        uint256 value
    ) internal {
        balanceOf[from][id] = balanceOf[from][id].sub(value);

        emit TransferSingle(msg.sender, from, address(0), id, value);
    }

    function _transferSingle(
        address from,
        address to,
        uint256 id,
        uint256 value
    ) internal {
        require(to != address(0), "No 0 address");

        balanceOf[from][id] = balanceOf[from][id].sub(value);
        balanceOf[to][id] = balanceOf[to][id].add(value);

        emit TransferSingle(msg.sender, from, to, id, value);
    }

    function _transferBatch(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata values
    ) internal {
        require(to != address(0), "No 0 address");


        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 value = values[i];
            balanceOf[from][id] = balanceOf[from][id].sub(value);
            balanceOf[to][id] = balanceOf[to][id].add(value);
        }

        emit TransferBatch(msg.sender, from, to, ids, values);
    }

    function _requireTransferAllowed(address from) internal view {
        require(from == msg.sender || isApprovedForAll[from][msg.sender] == true, "Transfer not allowed");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external override {
        _requireTransferAllowed(from);

        _transferSingle(from, to, id, value);

        if (to.isContract()) {
            require(
                IERC1155TokenReceiver(to).onERC1155Received(msg.sender, from, id, value, data) ==
                    bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)")),
                "Wrong return value"
            );
        }
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override {
        require(ids.length == values.length, "ERC1155: Length mismatch");
        _requireTransferAllowed(from);

        _transferBatch(from, to, ids, values);

        if (to.isContract()) {
            require(
                IERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, from, ids, values, data) ==
                    bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)")),
                "Wrong return value"
            );
        }
    }

    function setApprovalForAll(address operator, bool approved) external override {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }
}
