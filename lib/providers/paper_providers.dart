import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../core/models/paper_model.dart';
import '../features/papers/data/paper_repository.dart';

part 'paper_providers.g.dart';

@immutable
class PaperSearchFilters {
  final String query;
  final AssessmentType? type;
  final int? year;
  final String? instructor;

  const PaperSearchFilters({
    this.query = '',
    this.type,
    this.year,
    this.instructor,
  });

  PaperSearchFilters copyWith({
    String? query,
    AssessmentType? type,
    int? year,
    String? instructor,
  }) {
    return PaperSearchFilters(
      query: query ?? this.query,
      type: type ?? this.type,
      year: year ?? this.year,
      instructor: instructor ?? this.instructor,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PaperSearchFilters &&
            runtimeType == other.runtimeType &&
            query == other.query &&
            type == other.type &&
            year == other.year &&
            instructor == other.instructor;
  }

  @override
  int get hashCode => Object.hash(query, type, year, instructor);
}

@riverpod
OfflinePaperRepository paperRepository(Ref ref) {
  // Firebase repository (disabled for offline dev)
  // return PaperRepository(FirebaseFirestore.instance, FirebaseStorage.instance);
  return OfflinePaperRepository();
}

@riverpod
Future<List<Paper>> recentPapers(Ref ref) {
  return ref.watch(paperRepositoryProvider).getRecentPapers();
}

@riverpod
Future<List<Paper>> searchPapers(Ref ref, PaperSearchFilters filters) {
  return ref.watch(paperRepositoryProvider).searchPapers(
        query: filters.query,
        type: filters.type,
        year: filters.year,
        instructor: filters.instructor,
      );
}
