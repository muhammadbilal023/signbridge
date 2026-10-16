import 'package:flutter/material.dart';

/// Fifty sample vocabulary entries for the prototype. Confirm regional signs with PSL/ASL educators before production.
const kSigns = [
  'Hello',
  'Thank you',
  'Yes',
  'No',
  'Please',
  'Sorry',
  'Help',
  'Water',
  'Food',
  'Doctor',
  'Medicine',
  'Pain',
  'Emergency',
  'Name',
  'Good morning',
  'How are you',
  'Where',
  'Money',
  'Bank',
  'School',
  'Friend',
  'Family',
  'Wait',
  'Open',
  'Close',
  'Goodbye',
  'Welcome',
  'Love',
  'Happy',
  'Sad',
  'Need',
  'Want',
  'Understand',
  'Again',
  'Stop',
  'Go',
  'Come',
  'Eat',
  'Drink',
  'Home',
  'Work',
  'Today',
  'Tomorrow',
  'Yesterday',
  'Time',
  'Phone',
  'Bathroom',
  'Bus',
  'Train',
  'Police',
];

const kPhrases = [
  'Hello how are you',
  'I need help',
  'Thank you',
  'Please wait'
];

const kFilters = ['All', 'Sign→Text', 'Text→Sign', 'Live'];

class HistoryItem {
  final String type, title, detail, date;
  const HistoryItem(this.type, this.title, this.detail, this.date);
}

const kHistory = [
  HistoryItem('Sign→Text', 'Hello, I need help',
      '3 signs recognised • avg confidence 92%', 'Today, 10:24 AM'),
  HistoryItem('Text→Sign', 'Thank you very much', '3 sign clips played',
      'Today, 9:05 AM'),
  HistoryItem('Live', 'Session SB-4821',
      '12 min • captions on • mood mostly Happy', 'Yesterday'),
  HistoryItem('Sign→Text', 'Where is the doctor',
      '4 signs recognised • avg confidence 88%', 'Yesterday'),
  HistoryItem('Live', 'Session SB-1170',
      '5 min • captions on • mood mostly Neutral', '2 days ago'),
  HistoryItem('Text→Sign', 'Please wait', '2 sign clips played', '3 days ago'),
];

IconData iconFor(String t) => t == 'Live'
    ? Icons.video_call
    : t == 'Text→Sign'
        ? Icons.record_voice_over
        : Icons.sign_language;
