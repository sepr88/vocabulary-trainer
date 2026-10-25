import 'proficiency_level.dart';

class TrainingTopic {
  const TrainingTopic({
    required this.id,
    required this.label,
    required this.level,
  });

  final String id;
  final String label;
  final ProficiencyLevel level;
}

abstract final class TrainingTopics {
  static const vocabulary = <TrainingTopic>[
    TrainingTopic(
      id: 'greetings-and-introductions',
      label: 'Greetings and introductions',
      level: ProficiencyLevel.beginner,
    ),
    TrainingTopic(
      id: 'family-and-people',
      label: 'Family and people',
      level: ProficiencyLevel.beginner,
    ),
    TrainingTopic(
      id: 'numbers-dates-and-time',
      label: 'Numbers, dates and time',
      level: ProficiencyLevel.beginner,
    ),
    TrainingTopic(
      id: 'food-and-drink',
      label: 'Food and drink',
      level: ProficiencyLevel.beginner,
    ),
    TrainingTopic(
      id: 'home-and-daily-routines',
      label: 'Home and daily routines',
      level: ProficiencyLevel.beginner,
    ),
    TrainingTopic(
      id: 'shopping-and-money',
      label: 'Shopping and money',
      level: ProficiencyLevel.beginner,
    ),
    TrainingTopic(
      id: 'travel-and-transport',
      label: 'Travel and transport',
      level: ProficiencyLevel.beginner,
    ),
    TrainingTopic(
      id: 'places-and-directions',
      label: 'Places and directions',
      level: ProficiencyLevel.beginner,
    ),
    TrainingTopic(
      id: 'health-and-the-body',
      label: 'Health and the body',
      level: ProficiencyLevel.beginner,
    ),
    TrainingTopic(
      id: 'weather-and-clothing',
      label: 'Weather and clothing',
      level: ProficiencyLevel.beginner,
    ),
    TrainingTopic(
      id: 'work-and-education',
      label: 'Work and education',
      level: ProficiencyLevel.advanced,
    ),
    TrainingTopic(
      id: 'society-and-politics',
      label: 'Society and politics',
      level: ProficiencyLevel.advanced,
    ),
    TrainingTopic(
      id: 'environment-and-climate',
      label: 'Environment and climate',
      level: ProficiencyLevel.advanced,
    ),
    TrainingTopic(
      id: 'media-and-technology',
      label: 'Media and technology',
      level: ProficiencyLevel.advanced,
    ),
    TrainingTopic(
      id: 'economy-and-finance',
      label: 'Economy and finance',
      level: ProficiencyLevel.advanced,
    ),
    TrainingTopic(
      id: 'culture-and-the-arts',
      label: 'Culture and the arts',
      level: ProficiencyLevel.advanced,
    ),
    TrainingTopic(
      id: 'emotions-and-relationships',
      label: 'Emotions and relationships',
      level: ProficiencyLevel.advanced,
    ),
    TrainingTopic(
      id: 'opinions-and-argumentation',
      label: 'Opinions and argumentation',
      level: ProficiencyLevel.advanced,
    ),
    TrainingTopic(
      id: 'law-and-public-services',
      label: 'Law and public services',
      level: ProficiencyLevel.advanced,
    ),
    TrainingTopic(
      id: 'science-and-health',
      label: 'Science and health',
      level: ProficiencyLevel.advanced,
    ),
  ];

  static const conjugation = <TrainingTopic>[
    TrainingTopic(
      id: 'daily-life-and-home',
      label: 'Daily life and home',
      level: ProficiencyLevel.beginner,
    ),
    TrainingTopic(
      id: 'movement-and-travel',
      label: 'Movement and travel',
      level: ProficiencyLevel.beginner,
    ),
    TrainingTopic(
      id: 'communication-and-social-life',
      label: 'Communication and social life',
      level: ProficiencyLevel.beginner,
    ),
    TrainingTopic(
      id: 'work-and-education',
      label: 'Work and education',
      level: ProficiencyLevel.advanced,
    ),
    TrainingTopic(
      id: 'opinions-and-ideas',
      label: 'Opinions and ideas',
      level: ProficiencyLevel.advanced,
    ),
    TrainingTopic(
      id: 'society-and-change',
      label: 'Society and change',
      level: ProficiencyLevel.advanced,
    ),
  ];

  static TrainingTopic? vocabularyById(String id) {
    for (final topic in vocabulary) {
      if (topic.id == id) return topic;
    }
    return null;
  }

  static TrainingTopic? conjugationById(String id) {
    for (final topic in conjugation) {
      if (topic.id == id) return topic;
    }
    return null;
  }
}
