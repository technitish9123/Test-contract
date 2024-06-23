// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EVCharging {

    struct EVOwner {
        address ownerAddress;
        string name;
        bool isRegistered;
    }

    struct ChargingStation {
        address stationAddress;
        string name;
        bool isRegistered;
        uint ratePerKW; // Charging rate in Wei per KW
        uint256 balance; // Balance for the station to buy electricity
    }

    struct ChargeSession {
        address ownerAddress;
        address stationAddress;
        uint256 startTime;
        uint256 endTime;
        uint256 energyConsumed; // in KW
        bool isComplete;
        bool isPaid;
    }

    address public solutionProvider;
    mapping(address => EVOwner) public evOwners;
    mapping(address => ChargingStation) public chargingStations;
    mapping(bytes32 => ChargeSession) public chargeSessions;

    event EVOwnerRegistered(address indexed owner, string name);
    event ChargingStationRegistered(address indexed station, string name, uint ratePerKW);
    event ChargeSessionStarted(bytes32 indexed sessionId, address indexed owner, address indexed station);
    event ChargeSessionEnded(bytes32 indexed sessionId, uint256 energyConsumed);
    event PaymentCompleted(bytes32 indexed sessionId, uint256 amount);
    event ElectricityPurchased(address indexed station, uint256 amount);

    modifier onlySolutionProvider() {
        require(msg.sender == solutionProvider, "Only solution provider can perform this action");
        _;
    }

    modifier onlyRegisteredEVOwner() {
        require(evOwners[msg.sender].isRegistered, "Only registered EV owners can perform this action");
        _;
    }

    modifier onlyRegisteredChargingStation() {
        require(chargingStations[msg.sender].isRegistered, "Only registered charging stations can perform this action");
        _;
    }

    constructor() {
        solutionProvider = msg.sender;
    }

    function registerEVOwner(string memory _name) public {
        require(!evOwners[msg.sender].isRegistered, "EV Owner is already registered");

        evOwners[msg.sender] = EVOwner({
            ownerAddress: msg.sender,
            name: _name,
            isRegistered: true
        });

        emit EVOwnerRegistered(msg.sender, _name);
    }

    function registerChargingStation(string memory _name, uint _ratePerKW) public {
        require(!chargingStations[msg.sender].isRegistered, "Charging Station is already registered");

        chargingStations[msg.sender] = ChargingStation({
            stationAddress: msg.sender,
            name: _name,
            isRegistered: true,
            ratePerKW: _ratePerKW,
            balance: 0
        });

        emit ChargingStationRegistered(msg.sender, _name, _ratePerKW);
    }

    function startChargeSession(address _stationAddress) public onlyRegisteredEVOwner {
        require(chargingStations[_stationAddress].isRegistered, "Charging Station is not registered");

        bytes32 sessionId = keccak256(abi.encodePacked(msg.sender, _stationAddress, block.timestamp));
        chargeSessions[sessionId] = ChargeSession({
            ownerAddress: msg.sender,
            stationAddress: _stationAddress,
            startTime: block.timestamp,
            endTime: 0,
            energyConsumed: 0,
            isComplete: false,
            isPaid: false
        });

        emit ChargeSessionStarted(sessionId, msg.sender, _stationAddress);
    }

    function endChargeSession(bytes32 _sessionId, uint256 _energyConsumed) public onlyRegisteredChargingStation {
        ChargeSession storage session = chargeSessions[_sessionId];
        require(session.stationAddress == msg.sender, "Only the respective charging station can end the session");
        require(!session.isComplete, "Charge session is already completed");

        session.endTime = block.timestamp;
        session.energyConsumed = _energyConsumed;
        session.isComplete = true;

        emit ChargeSessionEnded(_sessionId, _energyConsumed);
    }

    function payForChargeSession(bytes32 _sessionId) public payable onlyRegisteredEVOwner {
        ChargeSession storage session = chargeSessions[_sessionId];
        require(session.ownerAddress == msg.sender, "Only the respective EV owner can pay for the session");
        require(session.isComplete, "Charge session is not completed yet");
        require(!session.isPaid, "Charge session is already paid");

        uint256 amountDue = session.energyConsumed * chargingStations[session.stationAddress].ratePerKW;
        require(msg.value >= amountDue, "Insufficient payment");

        payable(session.stationAddress).transfer(amountDue);
        session.isPaid = true;

        emit PaymentCompleted(_sessionId, amountDue);
    }

    // Function for charging stations to buy electricity from the solution provider
    function buyElectricity(uint256 _amount) public payable onlyRegisteredChargingStation {
        require(msg.value == _amount, "Incorrect amount sent");

        chargingStations[msg.sender].balance += _amount;
        payable(solutionProvider).transfer(_amount);

        emit ElectricityPurchased(msg.sender, _amount);
    }

    // Function to withdraw any excess payment to the solution provider
    function withdraw() public onlySolutionProvider {
        payable(solutionProvider).transfer(address(this).balance);
    }
}
