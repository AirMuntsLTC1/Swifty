// lib/model/ad_campaign.dart
/// One active ad campaign from public.ad_campaigns.
class AdCampaign {
  const AdCampaign({
    required this.id,
    required this.advertiserName,
    required this.advertiserHandle,
    this.advertiserAvatarUrl,
    this.advertiserVerified = false,
    required this.headline,
    this.body,
    this.imageUrl,
    this.ctaLabel = 'Learn more',
    required this.ctaUrl,
  });

  final String id;
  final String advertiserName;
  final String advertiserHandle;
  final String? advertiserAvatarUrl;
  final bool advertiserVerified;
  final String headline;
  final String? body;
  final String? imageUrl;
  final String ctaLabel;
  final String ctaUrl;

  factory AdCampaign.fromMap(Map<String, dynamic> row) {
    return AdCampaign(
      id: row['id'].toString(),
      advertiserName: (row['advertiser_name'] ?? '').toString(),
      advertiserHandle: (row['advertiser_handle'] ?? '').toString(),
      advertiserAvatarUrl: row['advertiser_avatar_url']?.toString(),
      advertiserVerified: row['advertiser_verified'] == true,
      headline: (row['headline'] ?? '').toString(),
      body: row['body']?.toString(),
      imageUrl: row['image_url']?.toString(),
      ctaLabel: (row['cta_label'] ?? 'Learn more').toString(),
      ctaUrl: (row['cta_url'] ?? '').toString(),
    );
  }
}
