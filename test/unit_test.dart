import 'package:flutter_test/flutter_test.dart';
import 'package:injustice/data/models/injustice_post.dart';
import 'package:injustice/core/location_data.dart';

void main() {
  group('InjusticePost Model Tests', () {
    test('Post should correctly serialize to JSON', () {
      final post = InjusticePost(
        id: '123',
        content: 'Test content',
        category: 'Corruption',
        timestamp: DateTime(2024, 1, 1),
        evidenceUrl: 'https://test.com/image.jpg',
        state: 'Maharashtra',
        district: 'Mumbai City',
        city: 'Mumbai',
      );

      final json = post.toJson();
      expect(json['id'], '123');
      expect(json['category'], 'Corruption');
      expect(json['state'], 'Maharashtra');
    });

    test('Post should correctly deserialize from JSON', () {
      final json = {
        'id': '456',
        'content': 'JSON content',
        'category': 'Police',
        'timestamp': '2024-01-01T00:00:00.000',
        'evidenceUrl': 'https://test.com/doc.pdf',
        'state': 'Delhi',
        'district': 'New Delhi',
        'city': 'Delhi',
      };

      final post = InjusticePost.fromJson(json);
      expect(post.id, '456');
      expect(post.category, 'Police');
      expect(post.state, 'Delhi');
    });
  });

  group('Location Data Tests', () {
    test('States and districts should not be empty', () {
      expect(LocationData.statesAndDistricts.isNotEmpty, true);
    });

    test('Maharashtra should contain Pune', () {
      expect(LocationData.statesAndDistricts['Maharashtra']?.contains('Pune'), true);
    });
  });

  // Note: Difficulty calculation test is private but we can test it indirectly 
  // if we expose it or just test the logic if moved to a helper.
  // Since it's currently static in DataService, we'll keep it simple.
}
