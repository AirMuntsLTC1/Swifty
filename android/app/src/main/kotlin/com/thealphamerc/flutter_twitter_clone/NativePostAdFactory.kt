package com.thealphamerc.flutter_twitter_clone

import android.content.Context
import android.view.LayoutInflater
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

/// Draws a Google native ad in the same layout as a Swifly post.
/// Registered in MainActivity under the factory id "swiflyPostAd".
class NativePostAdFactory(private val context: Context) :
    GoogleMobileAdsPlugin.NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val adView = LayoutInflater.from(context)
            .inflate(R.layout.native_post_ad, null) as NativeAdView

        val icon = adView.findViewById<ImageView>(R.id.ad_icon)
        val headline = adView.findViewById<TextView>(R.id.ad_headline)
        val body = adView.findViewById<TextView>(R.id.ad_body)
        val cta = adView.findViewById<Button>(R.id.ad_cta)
        val media = adView.findViewById<MediaView>(R.id.ad_media)

        headline.text = nativeAd.headline ?: ""
        adView.headlineView = headline

        body.text = nativeAd.body ?: ""
        adView.bodyView = body

        cta.text = nativeAd.callToAction ?: "Learn more"
        adView.callToActionView = cta

        val iconDrawable = nativeAd.icon?.drawable
        if (iconDrawable != null) {
            icon.setImageDrawable(iconDrawable)
        }
        adView.iconView = icon

        adView.mediaView = media

        adView.setNativeAd(nativeAd)
        return adView
    }
}
