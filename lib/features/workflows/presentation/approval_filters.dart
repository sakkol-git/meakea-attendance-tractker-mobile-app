import 'package:flutter/material.dart';

class ApprovalFilters extends StatelessWidget {
  final String requestType, status, sort;
  final int minAgeDays;
  final bool canReviewRequests;
  final ValueChanged<String> onRequestType, onStatus, onSort;
  final ValueChanged<int> onMinAgeDays;
  const ApprovalFilters({
    super.key,
    required this.requestType,
    required this.status,
    required this.sort,
    required this.minAgeDays,
    required this.canReviewRequests,
    required this.onRequestType,
    required this.onStatus,
    required this.onSort,
    required this.onMinAgeDays,
  });
  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('Filter and sort'),
    children: [
      DropdownButtonFormField<String>(
        initialValue: requestType,
        decoration: const InputDecoration(labelText: 'Request type'),
        items: [
          DropdownMenuItem(value: '', child: Text('All types')),
          DropdownMenuItem(value: 'leave', child: Text('Leave')),
          if (canReviewRequests)
            DropdownMenuItem(value: 'request', child: Text('Requests')),
          DropdownMenuItem(value: 'correction', child: Text('Corrections')),
        ],
        onChanged: (value) => onRequestType(value ?? ''),
      ),
      DropdownButtonFormField<int>(
        initialValue: minAgeDays,
        decoration: const InputDecoration(labelText: 'Waiting age'),
        items: const [
          DropdownMenuItem(value: 0, child: Text('Any age')),
          DropdownMenuItem(value: 1, child: Text('At least 1 day')),
          DropdownMenuItem(value: 3, child: Text('At least 3 days')),
          DropdownMenuItem(value: 7, child: Text('At least 7 days')),
        ],
        onChanged: (value) => onMinAgeDays(value ?? 0),
      ),
      DropdownButtonFormField<String>(
        initialValue: status,
        decoration: const InputDecoration(labelText: 'Status'),
        items: const [
          DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
          DropdownMenuItem(value: 'APPROVED', child: Text('Approved')),
          DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
        ],
        onChanged: (value) => onStatus(value ?? 'PENDING'),
      ),
      DropdownButtonFormField<String>(
        initialValue: sort,
        decoration: const InputDecoration(labelText: 'Sort'),
        items: const [
          DropdownMenuItem(value: 'oldest', child: Text('Oldest first')),
          DropdownMenuItem(value: 'newest', child: Text('Newest first')),
        ],
        onChanged: (value) => onSort(value ?? 'oldest'),
      ),
    ],
  );
}
