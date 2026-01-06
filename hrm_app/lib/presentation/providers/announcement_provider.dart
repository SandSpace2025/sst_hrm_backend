import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/data/repositories/announcement_repository.dart';
import 'package:hrm_app/data/models/announcement_model.dart';
import 'network_provider.dart';

class AnnouncementProvider with ChangeNotifier {
  final AnnouncementRepository _repository = AnnouncementRepository();

  List<AnnouncementModel> _announcements = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMoreData = true;
  String? _selectedAudience;
  String? _selectedPriority;

  List<AnnouncementModel> get announcements => _announcements;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMoreData => _hasMoreData;
  String? get selectedAudience => _selectedAudience;
  String? get selectedPriority => _selectedPriority;

  static const String _cacheBoxName = 'announcementCache';

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void setFilters({String? audience, String? priority}) {
    _selectedAudience = audience;
    _selectedPriority = priority;
    notifyListeners();
  }

  void clearFilters() {
    _selectedAudience = null;
    _selectedPriority = null;
    notifyListeners();
  }

  Future<bool> _isOnlineInternal(BuildContext? context) async {
    try {
      if (context != null) {
        final network = Provider.of<NetworkProvider>(context, listen: false);

        // ignore: unnecessary_null_comparison
        if (network != null) {
          return await network.checkConnection();
        }
      }
    } catch (_) {}

    final conn = await Connectivity().checkConnectivity();
    // ignore: unrelated_type_equality_checks
    return conn != ConnectivityResult.none;
  }

  Future<void> loadAnnouncements(
    String token, {
    bool refresh = false,
    BuildContext? context,
    bool onlyMine = false,
  }) async {
    if (_isLoading) return;

    if (refresh) {
      _currentPage = 1;
      _announcements.clear();
      _hasMoreData = true;
    }

    if (!_hasMoreData) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final isOnline = await _isOnlineInternal(context);

      final Box cacheBox = Hive.box(_cacheBoxName);

      if (!isOnline) {
        // Cached data fallback (does not support 'onlyMine' filter effectively)
        // Ignoring 'onlyMine' for offline cache or we would need to filter locally.
        // For now, returning all cached items if offline.
        final cachedData = cacheBox.get('announcements');
        if (cachedData != null) {
          _announcements = (cachedData as List)
              .map(
                (e) => AnnouncementModel.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList();
          if (refresh && context != null) {
            Fluttertoast.showToast(
              msg: '⚠️ Offline: showing cached announcements',
              backgroundColor: Colors.orange,
              textColor: Colors.white,
            );
          }
        } else {
          if (refresh && context != null) {
            Fluttertoast.showToast(
              msg: '⚠️ Offline and no cached announcements available',
              backgroundColor: Colors.red,
              textColor: Colors.white,
            );
          }
          _error = 'No cached announcements available';
        }
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await _repository.getAnnouncements(
        token,
        page: _currentPage,
        limit: 10,
        audience: _selectedAudience,
        priority: _selectedPriority,
        onlyMine: onlyMine,
      );

      final List<dynamic> announcementsData = response['announcements'] ?? [];
      final List<AnnouncementModel> newAnnouncements = announcementsData
          .map((data) => AnnouncementModel.fromJson(data))
          .toList();

      if (refresh) {
        _announcements = newAnnouncements;
      } else {
        _announcements.addAll(newAnnouncements);
      }

      try {
        await cacheBox.put(
          'announcements',
          _announcements.map((a) => a.toJson()).toList(),
        );
      } catch (e) {
        if (kDebugMode) {}
      }

      final pagination = response['pagination'];
      _hasMoreData = _currentPage < (pagination?['totalPages'] ?? 1);
      _currentPage++;

      _error = null;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {}
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAnnouncementsForAudience(
    String audience,
    String token, {
    bool refresh = false,
    BuildContext? context,
  }) async {
    if (_isLoading) return;

    if (refresh) {
      _currentPage = 1;
      _announcements.clear();
      _hasMoreData = true;
    }

    if (!_hasMoreData) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final isOnline = await _isOnlineInternal(context);
      final Box cacheBox = Hive.box(_cacheBoxName);

      if (!isOnline) {
        final cachedData = cacheBox.get('announcements');
        if (cachedData != null) {
          _announcements = (cachedData as List)
              .map(
                (e) => AnnouncementModel.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList();
          if (refresh && context != null) {
            Fluttertoast.showToast(
              msg: '⚠️ Offline: showing cached announcements',
              backgroundColor: Colors.orange,
              textColor: Colors.white,
            );
          }
        } else {
          if (refresh && context != null) {
            Fluttertoast.showToast(
              msg: '⚠️ Offline and no cached announcements available',
              backgroundColor: Colors.red,
              textColor: Colors.white,
            );
          }
          _error = 'No cached announcements available';
        }
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await _repository.getAnnouncementsForAudience(
        audience,
        token,
        page: _currentPage,
        limit: 10,
      );

      final List<dynamic> announcementsData = response['announcements'] ?? [];
      final List<AnnouncementModel> newAnnouncements = announcementsData
          .map((data) => AnnouncementModel.fromJson(data))
          .toList();

      if (refresh) {
        _announcements = newAnnouncements;
      } else {
        _announcements.addAll(newAnnouncements);
      }

      try {
        await cacheBox.put(
          'announcements',
          _announcements.map((a) => a.toJson()).toList(),
        );
      } catch (e) {
        if (kDebugMode) {}
      }

      final pagination = response['pagination'];
      _hasMoreData = _currentPage < (pagination?['totalPages'] ?? 1);
      _currentPage++;

      _error = null;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {}
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createAnnouncement(
    Map<String, dynamic> data,
    String token,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _repository.createAnnouncement(data, token);
      final announcement = AnnouncementModel.fromJson(response['announcement']);

      _announcements.insert(0, announcement);

      try {
        final Box cacheBox = Hive.box(_cacheBoxName);
        final cached = cacheBox.get('announcements') as List? ?? [];
        final updated = [announcement.toJson(), ...cached];
        await cacheBox.put('announcements', updated);
      } catch (_) {}

      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateAnnouncement(
    String announcementId,
    Map<String, dynamic> data,
    String token,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _repository.updateAnnouncement(
        announcementId,
        data,
        token,
      );
      final updatedAnnouncement = AnnouncementModel.fromJson(
        response['announcement'],
      );

      final index = _announcements.indexWhere(
        (announcement) => announcement.id == announcementId,
      );
      if (index != -1) {
        _announcements[index] = updatedAnnouncement;

        try {
          final Box cacheBox = Hive.box(_cacheBoxName);
          final cached = (cacheBox.get('announcements') as List?) ?? [];
          final updatedCached = cached.map((c) {
            final map = Map<String, dynamic>.from(c);
            if (map['id'] == announcementId) {
              return updatedAnnouncement.toJson();
            }
            return map;
          }).toList();
          await cacheBox.put('announcements', updatedCached);
        } catch (_) {}
      }

      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteAnnouncement(String announcementId, String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.deleteAnnouncement(announcementId, token);

      _announcements.removeWhere(
        (announcement) => announcement.id == announcementId,
      );

      try {
        final Box cacheBox = Hive.box(_cacheBoxName);
        final cached = (cacheBox.get('announcements') as List?) ?? [];
        final updatedCached = cached.where((c) {
          final map = Map<String, dynamic>.from(c);
          return map['id'] != announcementId;
        }).toList();
        await cacheBox.put('announcements', updatedCached);
      } catch (_) {}

      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AnnouncementModel?> getAnnouncementById(
    String announcementId,
    String token,
  ) async {
    try {
      final response = await _repository.getAnnouncementById(
        announcementId,
        token,
      );
      return AnnouncementModel.fromJson(response['announcement']);
    } catch (e) {
      return null;
    }
  }

  Future<void> refreshAnnouncements(
    String token, {
    BuildContext? context,
  }) async {
    final isOnline = await _isOnlineInternal(context);
    if (!isOnline && context != null) {
      Fluttertoast.showToast(
        msg: '⚠️ Offline: showing cached announcements',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
    } else if (context != null) {
      Fluttertoast.showToast(
        msg: '🔄 Refreshing announcements...',
        backgroundColor: Colors.blue,
        textColor: Colors.white,
      );
    }
    await loadAnnouncements(token, refresh: true, context: context);
  }

  Future<void> loadMoreAnnouncements(
    String token, {
    BuildContext? context,
    bool onlyMine = false,
  }) async {
    if (!_isLoading && _hasMoreData) {
      await loadAnnouncements(
        token,
        refresh: false,
        context: context,
        onlyMine: onlyMine,
      );
    }
  }

  void clearData() {
    _announcements.clear();
    _currentPage = 1;
    _hasMoreData = true;
    _isLoading = false;
    _error = null;
    _selectedAudience = null;
    _selectedPriority = null;
    notifyListeners();
  }
}
