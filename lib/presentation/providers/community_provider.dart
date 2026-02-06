import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/community_model.dart';
import '../../data/models/community_member_model.dart';
import '../../data/repositories/community_repository.dart';

class CommunityProvider extends ChangeNotifier {
  final CommunityRepository _repository = CommunityRepository();

  List<CommunityModel> _communities = [];
  List<CommunityModel> _myCommunities = [];
  List<CommunityModel> _nearbyCommunities = [];
  List<CommunityMemberModel> _pendingRequests = [];
  CommunityModel? _selectedCommunity;
  CommunityMemberModel? _currentMembership;
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _communitiesSubscription;

  List<CommunityModel> get communities => _communities;
  List<CommunityModel> get myCommunities => _myCommunities;
  List<CommunityModel> get nearbyCommunities => _nearbyCommunities;
  List<CommunityMemberModel> get pendingRequests => _pendingRequests;
  CommunityModel? get selectedCommunity => _selectedCommunity;
  CommunityMemberModel? get currentMembership => _currentMembership;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void startListening() {
    _communitiesSubscription?.cancel();
    _communitiesSubscription = _repository.watchAll().listen(
      (communities) {
        _communities = communities;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _communitiesSubscription?.cancel();
    super.dispose();
  }

  Future<void> loadMyCommunities(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _myCommunities = await _repository.getUserCommunities(userId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadNearbyCommunities(double latitude, double longitude) async {
    _isLoading = true;
    notifyListeners();

    try {
      _nearbyCommunities =
          await _repository.getNearbyCommunities(latitude, longitude);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<String?> createCommunity({
    required String name,
    required String description,
    required String creatorId,
    required double latitude,
    required double longitude,
    required double radius,
    required String address,
    bool isPublic = true,
    String? imageUrl,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final community = CommunityModel(
        id: '',
        name: name,
        description: description,
        creatorId: creatorId,
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        address: address,
        isPublic: isPublic,
        createdAt: DateTime.now(),
        imageUrl: imageUrl,
      );
      final id = await _repository.createCommunity(community);
      _isLoading = false;
      notifyListeners();
      return id;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  void selectCommunity(CommunityModel? community) {
    _selectedCommunity = community;
    notifyListeners();
  }

  Future<void> loadCommunityDetails(String communityId, String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _selectedCommunity = await _repository.getById(communityId);
      _currentMembership =
          await _repository.getUserMembership(communityId, userId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> requestToJoin(String communityId, String userId) async {
    try {
      await _repository.requestToJoin(communityId, userId);
      _currentMembership =
          await _repository.getUserMembership(communityId, userId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> loadPendingRequests(String communityId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _pendingRequests = await _repository.getPendingRequests(communityId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> approveRequest(String memberId, String approvedBy) async {
    try {
      await _repository.approveRequest(memberId, approvedBy);
      _pendingRequests.removeWhere((m) => m.id == memberId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectRequest(String memberId) async {
    try {
      await _repository.rejectRequest(memberId);
      _pendingRequests.removeWhere((m) => m.id == memberId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> leaveCommunity(String communityId, String userId) async {
    try {
      await _repository.leaveCommunity(communityId, userId);
      _myCommunities.removeWhere((c) => c.id == communityId);
      _currentMembership = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> isAdmin(String communityId, String userId) async {
    return await _repository.isAdmin(communityId, userId);
  }

  Future<bool> isMember(String communityId, String userId) async {
    return await _repository.isMember(communityId, userId);
  }

  Future<List<CommunityMemberModel>> getCommunityMembers(
      String communityId) async {
    return await _repository.getCommunityMembers(communityId);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
