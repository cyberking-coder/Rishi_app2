import '../entities/audio_summary.dart';
import '../entities/category_summary.dart';
import '../entities/continue_listening_item.dart';

abstract class HomeRepository {
  Future<List<AudioSummary>> getFeaturedAudios();
  Future<List<AudioSummary>> getRecentlyAdded();
  Future<List<ContinueListeningItem>> getContinueListening();
  Future<List<CategorySummary>> getCategories();
}
