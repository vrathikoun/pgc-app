class AcademyVideo {
  final int id;
  final String title;
  final String section;
  final String youtubeId;
  final String? description;
  final int sortOrder;

  const AcademyVideo({
    required this.id,
    required this.title,
    required this.section,
    required this.youtubeId,
    this.description,
    required this.sortOrder,
  });

  factory AcademyVideo.fromJson(Map<String, dynamic> json) {
    return AcademyVideo(
      id: json['id'],
      title: json['title'],
      section: json['section'],
      youtubeId: json['youtube_id'],
      description: json['description'],
      sortOrder: json['sort_order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'section': section,
        'youtube_id': youtubeId,
        'description': description,
        'sort_order': sortOrder,
      };
}
