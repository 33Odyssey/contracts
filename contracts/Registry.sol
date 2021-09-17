// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

// CREATE2 -- contract deployment.
import "@openzeppelin/contracts/utils/Create2.sol";

// Access Control
import "@openzeppelin/contracts/access/Ownable.sol";

// Protocol Components
import { Forwarder } from "./Forwarder.sol";
import { ProtocolControl } from "./ProtocolControl.sol";

contract Registry is Ownable {
    // NFTLabs treasury
    address public nftlabsTreasury;

    // `Forwarder` for gasless transacitons
    address public forwarder;

    struct ControlCenters {
        // Total number of versions
        uint256 latestVersion;
        // Version number => protocol control center address
        mapping(uint256 => address) protocolControl;
    }

    mapping(address => ControlCenters) public controlCenters;

    // Emitted on protocol deployment
    event DeployedProtocol(address indexed deployer, address indexed protocolControl, uint256 version);

    // Emitted in constructor
    event DeployedForwarder(address forwarder);

    constructor(address _nftlabs) {
        nftlabsTreasury = _nftlabs;

        bytes32 salt = keccak256(abi.encodePacked(block.number, msg.sender));
        bytes memory forwarderByteCode = abi.encodePacked(type(Forwarder).creationCode);
        forwarder = Create2.deploy(0, salt, forwarderByteCode);

        emit DeployedForwarder(forwarder);
    }

    /// @dev Deploys the control center, pack and market components of the protocol.
    function deployProtocol() external {
        bytes32 salt = keccak256(abi.encodePacked(block.number, msg.sender));

        // Deploy `ProtocolControl`
        bytes memory protocolControlByteCode = abi.encodePacked(
            type(ProtocolControl).creationCode,
            abi.encode(msg.sender, nftlabsTreasury)
        );

        address protocolControlAddr = Create2.deploy(0, salt, protocolControlByteCode);

        uint256 currentVersion = controlCenters[msg.sender].latestVersion;
        controlCenters[msg.sender].protocolControl[currentVersion] = protocolControlAddr;
        controlCenters[msg.sender].latestVersion += 1;

        emit DeployedProtocol(msg.sender, protocolControlAddr, currentVersion);
    }

    /// @dev Returns the latest version of protocol control
    function getLatestVersion(address _protocolDeployer) external view returns (uint256) {
        return controlCenters[_protocolDeployer].latestVersion;
    }

    /// @dev Returns the protocol control address for the given version
    function getProtocolControl(address _protocolDeployer, uint256 _version) external view returns (address) {
        return controlCenters[_protocolDeployer].protocolControl[_version];
    }
}
