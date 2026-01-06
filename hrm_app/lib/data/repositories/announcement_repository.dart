import 'package:hrm_app/core/services/http_service.dart';

class AnnouncementRepository {
  final HttpService _httpService;

  AnnouncementRepository({HttpService? httpService})
    : _httpService = httpService ?? HttpService();

  Future<void> createHRAnnouncement(
    String title,
    String message,
    String token, {
    String audience = 'employees',
    String priority = 'normal',
  }) async {
    final body = {
      'title': title,
      'message': message,
      'audience': audience,
      'priority': priority,
    };
    await _httpService.post(
      '/api/hr/announcements',
      token: token,
      body: body,
      expectedStatusCode: 201,
      isVoid: true,
      contextName: 'Create HR Announcement',
    );
  }

  Future<Map<String, dynamic>> getHRAnnouncements(
    String token, {
    int page = 1,
    bool onlyMine = false,
  }) async {
    final Map<String, dynamic> queryParams = {'page': page};
    if (onlyMine) {
      queryParams['onlyMine'] = 'true';
    }

    final response = await _httpService.get(
      '/api/hr/announcements',
      token: token,
      queryParams: queryParams,
      contextName: 'Get HR Announcements',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createAnnouncement(
    Map<String, dynamic> data,
    String token,
  ) async {
    final response = await _httpService.post(
      '/api/announcements',
      token: token,
      body: data,
      expectedStatusCode: 201,
      contextName: 'Create Announcement',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAnnouncements(
    String token, {
    int page = 1,
    int limit = 10,
    String? audience,
    String? priority,
    bool isActive = true,
    String sortBy = 'createdAt',
    String sortOrder = 'desc',
    bool onlyMine = false,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      'isActive': isActive,
      'sortBy': sortBy,
      'sortOrder': sortOrder,
    };
    if (audience != null) queryParams['audience'] = audience;
    if (priority != null) queryParams['priority'] = priority;
    if (onlyMine) queryParams['onlyMine'] = 'true';

    final response = await _httpService.get(
      '/api/announcements',
      token: token,
      queryParams: queryParams,
      contextName: 'Get Announcements',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAnnouncementsForAudience(
    String audience,
    String token, {
    int page = 1,
    int limit = 10,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};
    final response = await _httpService.get(
      '/api/announcements/audience/$audience',
      token: token,
      queryParams: queryParams,
      contextName: 'Get Audience Announcements',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAnnouncementById(
    String announcementId,
    String token,
  ) async {
    final response = await _httpService.get(
      '/api/announcements/$announcementId',
      token: token,
      contextName: 'Get Announcement By Id',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateAnnouncement(
    String announcementId,
    Map<String, dynamic> data,
    String token,
  ) async {
    final response = await _httpService.put(
      '/api/announcements/$announcementId',
      token: token,
      body: data,
      contextName: 'Update Announcement',
    );
    return response as Map<String, dynamic>;
  }

  Future<void> deleteAnnouncement(String announcementId, String token) async {
    await _httpService.delete(
      '/api/announcements/$announcementId',
      token: token,
      isVoid: true,
      contextName: 'Delete Announcement',
    );
  }
}
