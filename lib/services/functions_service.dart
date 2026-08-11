import 'package:cloud_functions/cloud_functions.dart';

class FunctionsService {
  final FirebaseFunctions _fn = FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<String> createFamily({
    required String name,
    required List<Map<String, String>> kids,
    required List<String> coParents,
  }) async {
    final res = await _fn.httpsCallable('createFamily').call<Map>({
      'name': name, 'kids': kids, 'coParents': coParents,
    });
    return res.data['familyId'] as String;
  }

  Future<void> joinFamily() => _fn.httpsCallable('joinFamily').call<Map>({});

  Future<void> decideRequest({
    required String familyId,
    required String requestId,
    required bool approve,
  }) =>
      _fn.httpsCallable('decideRequest').call<Map>({
        'familyId': familyId,
        'requestId': requestId,
        'decision': approve ? 'approve' : 'deny',
      });

  Future<void> deleteAccount() => _fn.httpsCallable('deleteAccount').call<Map>({});

  Future<void> recomputeBalances(String familyId) =>
      _fn.httpsCallable('recomputeBalances').call<Map>({'familyId': familyId});

  Future<void> runRecurringNow(String familyId) =>
      _fn.httpsCallable('runRecurringNow').call<Map>({'familyId': familyId});
}
