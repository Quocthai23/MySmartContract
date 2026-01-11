// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract LocationMemoryOnChain is ERC721, ERC721URIStorage, Ownable, ReentrancyGuard {
    
    uint256 private _nextTokenId = 1;

    // Độ chính xác tọa độ: 6 số thập phân. 
    // Ví dụ: 21.028511 => nhập là 21028511
    int256 constant PRECISION = 10**6; 
    
    // Khoảng cách cho phép (Sai số). Ví dụ 200 đơn vị ~ 20 mét
    int256 constant DISTANCE_THRESHOLD = 500; 

    struct TargetLocation {
        string name;        // Tên địa điểm
        int256 latitude;    // Vĩ độ mục tiêu
        int256 longitude;   // Kinh độ mục tiêu
        bool isActive;      // Trạng thái
        bool exists;
    }

    mapping(uint256 => TargetLocation) public locations;
    mapping(address => mapping(uint256 => bool)) public hasMintedAtLocation;

    event LocationCreated(uint256 indexed locationId, string name, int256 lat, int256 long);
    event MemoryMinted(address indexed user, uint256 indexed locationId, uint256 tokenId, string tokenURI);

    error LocationDoesNotExist();
    error LocationNotActive();
    error AlreadyMinted();
    error TooFarFromLocation(int256 userLat, int256 userLong, int256 targetLat, int256 targetLong);
    error SoulboundToken();

    // Sửa lại constructor cho đúng chuẩn OZ v5
    constructor() ERC721("GeoMemory", "GEM") Ownable(msg.sender) {}

    // --- ADMIN SETUP ---
    
    // Admin tạo địa điểm và tọa độ mục tiêu
    function addLocation(
        uint256 _id, 
        string calldata _name, 
        int256 _lat, 
        int256 _long
    ) external onlyOwner {
        locations[_id] = TargetLocation({
            name: _name,
            latitude: _lat,
            longitude: _long,
            isActive: true,
            exists: true
        });
        emit LocationCreated(_id, _name, _lat, _long);
    }

    function toggleLocation(uint256 _id, bool _isActive) external onlyOwner {
        require(locations[_id].exists, "Location not found");
        locations[_id].isActive = _isActive;
    }

    // --- USER MINT ---

    /**
     * @dev User gửi tọa độ của mình lên để Contract kiểm tra
     * @param _locationId ID địa điểm muốn check-in
     * @param _tokenURI Link ảnh user tự chụp (User Generated Content)
     * @param _userLat Vĩ độ hiện tại của User
     * @param _userLong Kinh độ hiện tại của User
     */
    function mintMemory(
        uint256 _locationId,
        string calldata _tokenURI,
        int256 _userLat,
        int256 _userLong
    ) external nonReentrant {
        TargetLocation memory target = locations[_locationId];

        // 1. Kiểm tra cơ bản
        if (!target.exists) revert LocationDoesNotExist();
        if (!target.isActive) revert LocationNotActive();
        if (hasMintedAtLocation[msg.sender][_locationId]) revert AlreadyMinted();

        // 2. LOGIC TÍNH KHOẢNG CÁCH TRÊN CONTRACT
        // Vì tính căn bậc 2 (Math.sqrt) trên Solidity rất tốn gas và phức tạp,
        // ta dùng phương pháp "Hộp giới hạn" (Bounding Box) - Hiệu số tọa độ.
        
        int256 diffLat = _userLat > target.latitude ? (_userLat - target.latitude) : (target.latitude - _userLat);
        int256 diffLong = _userLong > target.longitude ? (_userLong - target.longitude) : (target.longitude - _userLong);

        // Nếu khoảng cách sai lệch lớn hơn ngưỡng cho phép -> Báo lỗi
        if (diffLat > DISTANCE_THRESHOLD || diffLong > DISTANCE_THRESHOLD) {
            revert TooFarFromLocation(_userLat, _userLong, target.latitude, target.longitude);
        }

        // 3. Nếu ở đủ gần -> Cho phép Mint
        hasMintedAtLocation[msg.sender][_locationId] = true;
        uint256 tokenId = _nextTokenId++;

        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, _tokenURI);

        emit MemoryMinted(msg.sender, _locationId, tokenId, _tokenURI);
    }

    // --- SOULBOUND & OVERRIDES ---

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) {
            revert SoulboundToken();
        }
        return super._update(to, tokenId, auth);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}