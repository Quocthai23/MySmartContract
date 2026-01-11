// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract GeoSoulboundToken is ERC721, ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;

    // Hằng số cho validate tọa độ (giả sử độ chính xác 6 số thập phân - Microdegrees)
    // Ví dụ: 90 độ = 90,000,000
    int256 constant MAX_LATITUDE = 90 * 10**6; 
    int256 constant MIN_LATITUDE = -90 * 10**6;
    int256 constant MAX_LONGITUDE = 180 * 10**6;
    int256 constant MIN_LONGITUDE = -180 * 10**6;

    struct LocationDrop {
        string name;
        int256 latitude;
        int256 longitude;
        string tokenURI;
        bool isActive;
        bool exists; 
    }

    mapping(uint256 => LocationDrop) public locationDrops;
    mapping(address => mapping(uint256 => bool)) public hasCaughtAtLocation;

    // --- EVENTS ---
    event LocationSetup(uint256 indexed locationId, string name, int256 lat, int256 long);
    event LocationStatusChanged(uint256 indexed locationId, bool isActive);
    event TokenCaught(address indexed user, uint256 indexed locationId, uint256 tokenId);

    // --- ERRORS ---
    error SoulboundTokenCannotBeTransferred();
    error LocationNotActive();
    error LocationDoesNotExist();
    error LocationAlreadyExists(); // Lỗi trùng ID
    error AlreadyCaughtAtThisLocation();
    error InvalidCoordinates();    // Lỗi tọa độ phi lý

    constructor() ERC721("GeoHunterToken", "GHT") Ownable(msg.sender) {}


// Thêm mapping để kiểm tra locationId đã tồn tại
mapping(uint256 => bool) private _locationExists;

function setupLocation(
    uint256 _locationId,
    string memory _name,
    int256 _lat,
    int256 _long,
    string memory _tokenURI,
    bool _isActive
) external onlyOwner {
    // Kiểm tra trùng lặp
    require(!locationDrops[_locationId].exists, "Location ID already exists");

    // Kiểm tra tọa độ
    require(_lat >= MIN_LATITUDE && _lat <= MAX_LATITUDE, "Invalid latitude");
    require(_long >= MIN_LONGITUDE && _long <= MAX_LONGITUDE, "Invalid longitude");

    // Lưu trữ dữ liệu
    locationDrops[_locationId] = LocationDrop({
        name: _name,
        latitude: _lat,
        longitude: _long,
        tokenURI: _tokenURI,
        isActive: _isActive,
        exists: true
    });

    emit LocationSetup(_locationId, _name, _lat, _long);
}
    // 2. QUẢN LÝ TRẠNG THÁI ĐỊA ĐIỂM (Mới thêm)
    // Cho phép Admin tắt địa điểm nếu sự kiện kết thúc hoặc bảo trì
    function toggleLocationStatus(uint256 _locationId, bool _isActive) public onlyOwner {
        if (!locationDrops[_locationId].exists) {
            revert LocationDoesNotExist();
        }

        locationDrops[_locationId].isActive = _isActive;
        emit LocationStatusChanged(_locationId, _isActive);
    }

    // 3. BẮT TOKEN
    function catchToken(uint256 _locationId) public {
        // Kiểm tra ID có tồn tại không trước
        if (!locationDrops[_locationId].exists) {
            revert LocationDoesNotExist();
        }

        // Kiểm tra đang Active hay Inactive
        if (!locationDrops[_locationId].isActive) {
            revert LocationNotActive();
        }

        if (hasCaughtAtLocation[msg.sender][_locationId]) {
            revert AlreadyCaughtAtThisLocation();
        }

        uint256 tokenId = _nextTokenId++;
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, locationDrops[_locationId].tokenURI);

        hasCaughtAtLocation[msg.sender][_locationId] = true;

        emit TokenCaught(msg.sender, _locationId, tokenId);
    }

    // 4. SOULBOUND LOGIC
    function _update(address to, uint256 tokenId, address auth) internal override(ERC721) returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) {
            revert SoulboundTokenCannotBeTransferred();
        }
        return super._update(to, tokenId, auth);
    }

    // Boilerplate cho URI Storage
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}