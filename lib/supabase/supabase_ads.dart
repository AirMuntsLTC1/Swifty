// lib/supabase/supabase_ads.dart
//
// Ad calls. Kept in their own file so the main repository is unchanged.
import 'package:flutter_twitter_clone/model/ad_campaign.dart';
import 'package:flutter_twitter_clone/supabase/supabase_repository.dart';

extension SupabaseAds on SupabaseRepository {
  /// Active campaigns this user has not hidden, in random order.
  Future<List<AdCampaign>> fetchActiveAds({int limit = 10}) async {
    final rows = await db.rpc(
      'swifs_active_ads',
      params: {'lim': limit},
    );
    return List<Map<String, dynamic>>.from(rows as List)
        .map(AdCampaign.fromMap)
        .toList();
  }

  /// kind is 'impression', 'click' or 'hide'.
  Future<void> recordAdEvent(String campaignId, String kind) async {
    await db.rpc(
      'swifs_record_ad_event',
      params: {'campaign': campaignId, 'kind': kind},
    );
  }
}
