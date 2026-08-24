import 'dart:convert';

enum MediaPayloadType {
  text,
  voiceNote,
  image,
  geoMarker,
}

/// Structured rich media payload encapsulated inside encrypted DTN bundles.
class MediaPayload {
  final MediaPayloadType type;
  final String textContent;
  
  // Voice note attributes
  final int? audioDurationSec;
  final String? audioWaveformBase64;
  
  // Image attachment attributes
  final int? imageWidth;
  final int? imageHeight;
  final String? thumbnailBase64;
  
  // Tactical Geo-marker attributes
  final double? latitude;
  final double? longitude;
  final double? altitudeMeters;
  final String? geoLabel;
  final int? emergencySeverity; // 1 = Info, 2 = Warning, 3 = Critical SOS

  MediaPayload({
    required this.type,
    this.textContent = '',
    this.audioDurationSec,
    this.audioWaveformBase64,
    this.imageWidth,
    this.imageHeight,
    this.thumbnailBase64,
    this.latitude,
    this.longitude,
    this.altitudeMeters,
    this.geoLabel,
    this.emergencySeverity,
  });

  /// Helper factory for plain text
  factory MediaPayload.text(String text) {
    return MediaPayload(
      type: MediaPayloadType.text,
      textContent: text,
    );
  }

  /// Helper factory for voice note
  factory MediaPayload.voiceNote({
    required int durationSec,
    required String audioBase64,
    String? label,
  }) {
    return MediaPayload(
      type: MediaPayloadType.voiceNote,
      textContent: label ?? 'Voice Note (${durationSec}s)',
      audioDurationSec: durationSec,
      audioWaveformBase64: audioBase64,
    );
  }

  /// Helper factory for image attachment
  factory MediaPayload.image({
    required String imageBase64,
    required int width,
    required int height,
    String? caption,
  }) {
    return MediaPayload(
      type: MediaPayloadType.image,
      textContent: caption ?? 'Image attachment ($width x $height)',
      imageWidth: width,
      imageHeight: height,
      thumbnailBase64: imageBase64,
    );
  }

  /// Helper factory for tactical geo-marker / SOS
  factory MediaPayload.geoMarker({
    required double lat,
    required double lon,
    double? alt,
    required String label,
    int emergencySeverity = 1,
  }) {
    return MediaPayload(
      type: MediaPayloadType.geoMarker,
      textContent: label,
      latitude: lat,
      longitude: lon,
      altitudeMeters: alt,
      geoLabel: label,
      emergencySeverity: emergencySeverity,
    );
  }

  String serialize() => jsonEncode(toJson());

  static MediaPayload deserialize(String rawJson) {
    try {
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      return MediaPayload.fromJson(map);
    } catch (_) {
      // Fallback to plain text if not structured JSON
      return MediaPayload.text(rawJson);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.index,
      'text': textContent,
      if (audioDurationSec != null) 'audio_duration': audioDurationSec,
      if (audioWaveformBase64 != null) 'audio_data': audioWaveformBase64,
      if (imageWidth != null) 'image_width': imageWidth,
      if (imageHeight != null) 'image_height': imageHeight,
      if (thumbnailBase64 != null) 'thumbnail_data': thumbnailBase64,
      if (latitude != null) 'lat': latitude,
      if (longitude != null) 'lon': longitude,
      if (altitudeMeters != null) 'alt': altitudeMeters,
      if (geoLabel != null) 'geo_label': geoLabel,
      if (emergencySeverity != null) 'emergency_severity': emergencySeverity,
    };
  }

  factory MediaPayload.fromJson(Map<String, dynamic> json) {
    return MediaPayload(
      type: MediaPayloadType.values[json['type'] as int? ?? 0],
      textContent: json['text'] as String? ?? '',
      audioDurationSec: json['audio_duration'] as int?,
      audioWaveformBase64: json['audio_data'] as String?,
      imageWidth: json['image_width'] as int?,
      imageHeight: json['image_height'] as int?,
      thumbnailBase64: json['thumbnail_data'] as String?,
      latitude: (json['lat'] as num?)?.toDouble(),
      longitude: (json['lon'] as num?)?.toDouble(),
      altitudeMeters: (json['alt'] as num?)?.toDouble(),
      geoLabel: json['geo_label'] as String?,
      emergencySeverity: json['emergency_severity'] as int?,
    );
  }
}
