import '../entities/audio_summary.dart';
import '../entities/category_summary.dart';
import '../entities/continue_watching_item.dart';
import '../entities/video_summary.dart';

abstract class HomeRepository {
  Future<List<VideoSummary>> getFeaturedVideos();
  Future<List<AudioSummary>> getFeaturedAudios();
  Future<List<VideoSummary>> getRecentlyAdded();
  Future<List<ContinueWatchingItem>> getContinueWatching();
  Future<List<CategorySummary>> getCategories();
}
