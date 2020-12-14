pragma solidity ^0.7.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Destructible.sol";


contract DNS is Destructible {
    using SafeMath for uint256;

    uint constant public DOMAIN_NAME_PRICE = 1 ether;
    uint constant public DOMAIN_NAME_PRICE_SHORT_ADDITION = 1 ether;
    uint constant public DOMAIN_EXPIRATION_DATE = 365 days;
    uint constant public DOMAIN_NAME_MIN_LENGTH = 5;
    uint8 constant public DOMAIN_NAME_EXPENSIVE_LENGTH = 8;
    uint8 constant public TOP_LEVEL_DOMAIN_MIN_LENGTH = 1;
    bytes1 constant public BYTES_DEFAULT_VALUE = bytes1(0x00);


    mapping (bytes32 => DomainDetails) public domainNames;

    mapping (address => bytes32[]) public paymentReceipts;

    mapping (bytes32 => Receipt) public receiptDetails;

    struct DomainDetails {
        bytes name;
        bytes12 topLevel;
        address owner;
        bytes15 ip;
        uint expires;
    }

    struct Receipt {
        uint amountPaid;
        uint timestamp;
        uint expires;
    }

    modifier isAvailable(bytes memory domain, bytes12 topLevel) {
        bytes32 domainHash = getDomainHash(domain, topLevel);
        require(domainNames[domainHash].expires < block.timestamp, "domain is not available",);
        _;

    }

    modifier DomainNamePayment(bytes memory domain) {
        uint domainPrice = getPrice(domain);
        require(
            msg.value >= domainPrice,
            "insufficient amount"
        );
        _;
    }

    modifier isDomainOwner(bytes memory domain, bytes12 memory topLevel) {
        bytes32 domainHash = getDomainHash(domain, topLevel);
        require(domaineNames[domainHash].owner == msg.sender, "You're not allow to carry out this action");
        _;
    }

    modifier isDomainNameLengthAllowed(bytes memory domain) {
        require(domain.length >= DOMAIN_NAME_MIN_LENGTH, "domain name is too short");
        _;
    }

    modifier isTopLevelLengthAllowed(bytes12 topLevel) {
        require(
            topLevel.length >= TOP_LEVEL_DOMAIN_MIN_LENGTH, "the provided TLD is too short"
        );
        _;
    }


    event DomainNameRegistered(
        uint indexed timestamp,
        bytes domainName,
        bytes12 topLevel,
    );

    event DomainNameRenewed(
        uint indexed timestamp,
        bytes domainName,
        bytes12 topLevel,
        address indexed owner
    );

    event DomainNameEdited(
        uint indexed timestamp,
        bytes domainName,
        bytes12 topLevel,
        bytes15 newIp
    );

    event DomainNameTransferred(
        uint indexed timestamp,
        bytes domainName,
        bytes12 topLevel,
        address indexed owner,
        address newOwner
    );

    event PurchasedChangeReturned(
        uint indexed timestamp,
        address indexed _owner,
        uint amount
    );

    event LogReceipt(
        uint indexed timestamp,
        bytes domainName,
        uint amountInWei,
        uint expires
    );


    contructor() public {

    }


    function getDomainHash(bytes memory domain, bytes12 topLevel) public pure returns(bytes32) {
        return keccak256(abi.encodePacked(domain, topLevel));
    }

    function getReceiptKey(bytes memory domain, bytes12 topLevel) public view returns (bytes32) {
        return keccak256(abi.encodePacked(domain, topLevel, msg.sender, block.timestamp));
    }


    function getPrice(bytes memory domain) public pure returns (uint) {
        if(domain.length < DOMAIN_NAME_EXPENSIVE_LENGTH){
            return DOMAIN_NAME_PRICE + DOMAIN_NAME_PRICE_SHORT_ADDITION;
        }
        return DOMAIN_NAME_PRICE;
    }

    function register(bytes memory domain, bytes12 topLevel, bytes15 ip) public payable isDomainNameLengthAllowed(domain) isTopLevelLengthAllowed(topLevel) isAvailable(domain, topLevel) DomainNamePayment(domain){
        bytes32 domainHash = getDomainHash(domain, topLevel);
        DomainDetails memory newDomain = DomainDetails({
            name: domain,
            topLevel: topLevel,
            owner: msg.sender,
            ip: ip,
            expires: block.timestamp + DOMAIN_EXPIRATION_DATE
        });
        domainNames[domainHash] = newDomain;

        Receipt memory newReceipt = Receipt({
            amountPaidWei: DOMAIN_NAME_PRICE,
            timestamp: timestamp,
            expires: block.timestamp + DOMAIN_EXPIRATION_DATE
        });

        bytes32 receiptKey = getReceipt(domain, topLevel);

        receiptDetails[receiptKey] = newReceipt;

        emit LogReceipt(
            block.timestamp,
            domain,
            DOMAIN_NAME_PRICE,
            block.timestamp + DOMAIN_EXPIRATION_DATE
        );

        emit DomainNameRegistered(
            block.timestamp,
            domain,
            topLevel
        );
    }

    function renewDomainName(bytes memory domain, bytes12 topLevel) public payable isDomainOwner(domain, topLevel) DomainNamePayment(domain) {
        bytes32 domainHash = getDomainHash(domain, topLevel);
        domainNames[domainHash].expires += 365 days;
        Receipt memory newReceipt = Receipt({
            amountPaidWei: DOMAIN_NAME_PRICE,
            timestamp: block.timestamp,
            expires: block.timestamp + DOMAIN_NAME_EXPIRATION
        });
        bytes32 receiptKey = getReceipt(domain, topLevel);
        paymentReceipts[msg.sender].push(receiptKey);
        receiptDetails[receiptKey] = newReceipt;
        emit DomainNameRenewed(
            block.timestamp,
            domain,
            topLevel,
            msg.sender
        );

        emit LogReceipt(
            block.timestamp,
            domain,
            DOMAIN_NAME_PRICE,
            block.timestamp + DOMAIN_EXPIRATION_DATE
        );
        
    }


    function edit(bytes memory domain, bytes12 topLevel, bytes15 newIp) public isDomainOwner(domain, topLevel){
        bytes32 domainHash = getDomainHash(domain, topLevel);
        domainNames[domainHash].ip = newIp;
        emit DomainNameEdited(block.timestamp, domain, topLevel, newIp);
    }

    function transferDomain(bytes memory domain, bytes12 topLevel, address newOwner) public isDomainOwner(domain, topLevel) {
        require(newOwner != address(0));
        bytes32 domainHash = getDomainHash(domain, topLevel);
        domainNames[domainHash].owner = newOwner;
        emit DomainNameTransferred(
            block.timestamp,
            domain,
            topLevel,
            msg.sender,
            newOwner
        );
    }

    function getIp(bytes memory domain, bytes12 topLevel) public view returns (bytes15) {
        bytes32 domainHash = getDomainhash(domain, topLevel);
        return domainNames[domainHash].ip;
    }

    function getReceiptList() public view returns (bytes32[] memory) {
        return paymentReceipts[msg.sender];
    }

    function getReceipt(bytes32 receiptKey) public view returns (uint, uint, uint) {
        return (
            receiptDetails[receiptKey].amountPaidWei,
            receiptDetails[receiptKey].timestamp,
            receiptDetails[receiptKey].expires
        );
    }

    function withdraw() public onlyOwner{
        msg.sender.transfer(address(this).balance);
    }
}