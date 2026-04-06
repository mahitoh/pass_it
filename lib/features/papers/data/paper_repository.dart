// ignore_for_file: unused_import, unused_field
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/models/paper_model.dart';

class PaperRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  PaperRepository(this._firestore, this._storage);

  Future<List<Paper>> getRecentPapers() async {
    // Firebase online fetch (disabled for offline dev)
    // final query = await _firestore
    //     .collection('papers')
    //     .orderBy('uploadedAt', descending: true)
    //     .limit(10)
    //     .get();
    // return query.docs.map((doc) => Paper.fromJson(doc.data())).toList();
    throw UnimplementedError('Firebase is disabled for offline development.');
  }

  Future<List<Paper>> searchPapers({
    required String query,
    AssessmentType? type,
    int? year,
    String? instructor,
  }) async {
    final normalizedQuery = query.trim().toLowerCase();

    // Firestore full-text search is out of scope for UI scaffolding,
    // so we fetch a recent slice and apply filters client-side.
    final papers = await getRecentPapers();

    return papers.where((paper) {
      final matchesQuery = normalizedQuery.isEmpty ||
          paper.courseCode.toLowerCase().contains(normalizedQuery) ||
          paper.courseName.toLowerCase().contains(normalizedQuery);
      final matchesType = type == null || paper.type == type;
      final matchesYear = year == null || paper.year == year;
      final matchesInstructor = instructor == null ||
          paper.instructor.toLowerCase().contains(instructor.toLowerCase());
      return matchesQuery && matchesType && matchesYear && matchesInstructor;
    }).toList();
  }

  Future<void> uploadPaper(Paper paper, String filePath) async {
    // Firebase upload (disabled for offline dev)
    // final storageRef = _storage.ref().child('papers/${paper.id}');
    // await storageRef.putFile(File(filePath));
    // final fileUrl = await storageRef.getDownloadURL();
    // await _firestore.collection('papers').doc(paper.id).set(
    //       paper.copyWith(fileUrl: fileUrl).toJson(),
    //     );
    throw UnimplementedError('Firebase is disabled for offline development.');
  }
}

class OfflinePaperRepository {
  static final OfflinePaperRepository _instance = OfflinePaperRepository._internal();
  factory OfflinePaperRepository() => _instance;
  OfflinePaperRepository._internal();

  final List<Paper> _seed = [
    Paper(
      id: 'p1',
      courseCode: 'CS201',
      courseName: 'Data Structures',
      instructor: 'Dr. Foka',
      type: AssessmentType.finalExam,
      year: 2024,
      semester: 1,
      fileUrl: 'local://cs201-final.pdf',
      uploaderId: 'local-user',
      uploadedAt: DateTime.now().subtract(const Duration(days: 2)),
      upvotes: 42,
    ),
    Paper(
      id: 'p2',
      courseCode: 'MTH211',
      courseName: 'Linear Algebra',
      instructor: 'Prof. Ade',
      type: AssessmentType.midterm,
      year: 2023,
      semester: 2,
      fileUrl: 'local://mth211-midterm.pdf',
      uploaderId: 'local-user',
      uploadedAt: DateTime.now().subtract(const Duration(days: 6)),
      upvotes: 18,
    ),
    Paper(
      id: 'p3',
      courseCode: 'PHY101',
      courseName: 'General Physics',
      instructor: 'Dr. Hassan',
      type: AssessmentType.quiz,
      year: 2022,
      semester: 1,
      fileUrl: 'local://phy101-quiz.pdf',
      uploaderId: 'local-user',
      uploadedAt: DateTime.now().subtract(const Duration(days: 12)),
      upvotes: 9,
    ),
  ];

  Future<List<Paper>> getRecentPapers() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _seed;
  }

  Future<List<Paper>> searchPapers({
    required String query,
    AssessmentType? type,
    int? year,
    String? instructor,
  }) async {
    final normalizedQuery = query.trim().toLowerCase();
    final results = _seed.where((paper) {
      final matchesQuery = normalizedQuery.isEmpty ||
          paper.courseCode.toLowerCase().contains(normalizedQuery) ||
          paper.courseName.toLowerCase().contains(normalizedQuery);
      final matchesType = type == null || paper.type == type;
      final matchesYear = year == null || paper.year == year;
      final matchesInstructor = instructor == null ||
          paper.instructor.toLowerCase().contains(instructor.toLowerCase());
      return matchesQuery && matchesType && matchesYear && matchesInstructor;
    }).toList();
    return results;
  }

  Future<void> uploadPaper(Paper paper, String filePath) async {
    await Future.delayed(const Duration(milliseconds: 800));
    _seed.insert(0, paper);
  }

  void toggleUpvote(String paperId) {
    final index = _seed.indexWhere((p) => p.id == paperId);
    if (index == -1) return;
    final paper = _seed[index];
    _seed[index] = paper.copyWith(
      upvotes: paper.upvotes > 0 ? paper.upvotes - 1 : paper.upvotes + 1,
    );
  }
}
