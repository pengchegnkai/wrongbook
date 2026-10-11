/// providers/filter_provider.dart —— 筛选页选项（错因、掌握度等）
import 'package:flutter_riverpod/flutter_riverpod.dart';

const kErrorTypes = ['概念不清', '计算失误', '审题错误', '方法不会', '粗心大意', '时间不够', '其他'];
const kMasteryOptions = {'red': '🔴 未掌握', 'yellow': '🟡 模糊', 'green': '🟢 已掌握'};
const kVerificationStatuses = {'unverified': '待核验', 'verified': '已核验', 'invalid': '核验无效'};
const kAuthorityLevels = {'A': 'A 级（官方）', 'B': 'B 级（教育平台）', 'C': 'C 级（普通）'};

/// 当前选中筛选项（供筛选页 UI）
final selectedErrorTypeProvider = StateProvider<String?>((ref) => null);
final selectedMasteryProvider = StateProvider<String?>((ref) => null);
