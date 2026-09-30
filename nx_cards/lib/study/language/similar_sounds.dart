import 'dart:math';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/scheduling/learning_stage.dart';

bool isChineseLanguage(String? value) => {
  'chinese',
  'mandarin',
  'zh',
  'zh-cn',
  'zh-tw',
}.contains(value?.trim().toLowerCase());

class PinyinSyllable {
  const PinyinSyllable(this.spelling, this.tone);
  final String spelling;
  final int tone;
  String get key => '$spelling$tone';
  String get initial {
    for (final s in ['zh', 'ch', 'sh', ...'bpmfdtnlgkhjqxrzcs'.split('')]) {
      if (spelling.startsWith(s)) return s;
    }
    return '';
  }

  String get finalSound {
    final f = spelling.substring(initial.length);
    if (initial.isEmpty) {
      return const {
            'yi': 'i',
            'ya': 'ia',
            'ye': 'ie',
            'yao': 'iao',
            'you': 'iou',
            'yan': 'ian',
            'yin': 'in',
            'yang': 'iang',
            'ying': 'ing',
            'yong': 'iong',
            'yu': 'ü',
            'yue': 'üe',
            'yuan': 'üan',
            'yun': 'ün',
            'wu': 'u',
            'wa': 'ua',
            'wo': 'uo',
            'wai': 'uai',
            'wei': 'uei',
            'wan': 'uan',
            'wen': 'uen',
            'wang': 'uang',
            'weng': 'ueng',
          }[spelling] ??
          f;
    }
    if ({'j', 'q', 'x'}.contains(initial) && f.startsWith('u')) {
      return f.replaceFirst('u', 'ü');
    }
    return const {'iu': 'iou', 'ui': 'uei', 'un': 'uen'}[f] ?? f;
  }
}

final _syllables =
    '''
a ai an ang ao e ei en eng er o ou
ba bai ban bang bao bei ben beng bi bian biao bie bin bing bo bu
pa pai pan pang pao pei pen peng pi pian piao pie pin ping po pou pu
ma mai man mang mao me mei men meng mi mian miao mie min ming miu mo mou mu
fa fan fang fei fen feng fo fou fu
da dai dan dang dao de dei den deng di dia dian diao die ding diu dong dou du duan dui dun duo
ta tai tan tang tao te teng ti tian tiao tie ting tong tou tu tuan tui tun tuo
na nai nan nang nao ne nei nen neng ni nian niang niao nie nin ning niu nong nou nu nuan nuo nü nüe
la lai lan lang lao le lei leng li lia lian liang liao lie lin ling liu long lou lu luan lun luo lü lüe
ga gai gan gang gao ge gei gen geng gong gou gu gua guai guan guang gui gun guo
ka kai kan kang kao ke ken keng kong kou ku kua kuai kuan kuang kui kun kuo
ha hai han hang hao he hei hen heng hong hou hu hua huai huan huang hui hun huo
ji jia jian jiang jiao jie jin jing jiong jiu ju jue juan jun
qi qia qian qiang qiao qie qin qing qiong qiu qu que quan qun
xi xia xian xiang xiao xie xin xing xiong xiu xu xue xuan xun
zha zhai zhan zhang zhao zhe zhei zhen zheng zhi zhong zhou zhu zhua zhuai zhuan zhuang zhui zhun zhuo
cha chai chan chang chao che chen cheng chi chong chou chu chua chuai chuan chuang chui chun chuo
sha shai shan shang shao she shei shen sheng shi shou shu shua shuai shuan shuang shui shun shuo
ran rang rao re ren reng ri rong rou ru ruan rui run ruo
za zai zan zang zao ze zei zen zeng zi zong zou zu zuan zui zun zuo
ca cai can cang cao ce cen ceng ci cong cou cu cuan cui cun cuo
sa sai san sang sao se sen seng si song sou su suan sui sun suo
yi ya ye yao you yan yin yang ying yong yu yue yuan yun yo
wu wa wo wai wei wan wen wang weng
'''
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toSet();

/// Parse tone marks, numbers, apostrophes and joined words without losing ü.
List<PinyinSyllable> parsePinyin(String value) {
  const marked = {
    'a': 'āáǎà',
    'e': 'ēéěè',
    'i': 'īíǐì',
    'o': 'ōóǒò',
    'u': 'ūúǔù',
    'ü': 'ǖǘǚǜ',
  };
  var text = value
      .trim()
      .toLowerCase()
      .replaceAll('u:', 'ü')
      .replaceAll('v', 'ü')
      .replaceAll('u\u0308', 'ü');
  const accents = ['\u0304', '\u0301', '\u030c', '\u0300'];
  for (final entry in marked.entries) {
    for (var i = 0; i < 4; i++) {
      text = text.replaceAll('${entry.key}${accents[i]}', entry.value[i]);
    }
  }
  final result = <PinyinSyllable>[];
  for (final token in text.split(RegExp(r"[\s'’\-]+"))) {
    if (token.isEmpty) continue;
    final cache = <int, List<PinyinSyllable>?>{};
    List<PinyinSyllable>? split(int start) {
      if (start == token.length) return [];
      if (cache.containsKey(start)) return cache[start];
      for (var end = min(token.length, start + 7); end > start; end--) {
        var raw = token.substring(start, end), tone = 5, marks = 0;
        if (RegExp(r'[0-5]$').hasMatch(raw)) {
          tone = int.parse(raw[raw.length - 1]);
          if (tone == 0) tone = 5;
          raw = raw.substring(0, raw.length - 1);
          marks++;
        }
        for (final entry in marked.entries) {
          for (var i = 0; i < 4; i++) {
            if (raw.contains(entry.value[i])) {
              marks += entry.value[i].allMatches(raw).length;
              tone = i + 1;
              raw = raw.replaceAll(entry.value[i], entry.key);
            }
          }
        }
        if (marks > 1 || !_syllables.contains(raw)) continue;
        final rest = split(end);
        if (rest != null) {
          return cache[start] = [PinyinSyllable(raw, tone), ...rest];
        }
      }
      return cache[start] = null;
    }

    final parsed = split(0);
    if (parsed == null) return [];
    result.addAll(parsed);
  }
  return result;
}

bool _nearFinals(String a, String b) => const [
  {'ou', 'uo'},
  {'ou', 'iou'},
  {'i', 'ie'},
  {'iou', 'o'},
  {'an', 'ang'},
  {'en', 'eng'},
  {'in', 'ing'},
  {'u', 'ü'},
].any((pair) => pair.contains(a) && pair.contains(b));

/// A ranking heuristic for contrast practice, not an acoustic measurement.
double? pinyinDistance(List<PinyinSyllable> a, List<PinyinSyllable> b) {
  if (a.isEmpty || a.length != b.length) return null;
  var changed = 0, distance = 0.0;
  for (var i = 0; i < a.length; i++) {
    final x = a[i], y = b[i];
    if (x.spelling == y.spelling) {
      if (x.tone != y.tone) distance += .1;
      continue;
    }
    if (++changed > 1) return null;
    if (x.finalSound == y.finalSound) {
      distance += 1;
    } else if (_nearFinals(x.finalSound, y.finalSound) &&
        (x.initial == y.initial ||
            x.spelling.endsWith('ou') && y.spelling.endsWith('ou'))) {
      distance += 1.5;
    } else if (x.initial.isNotEmpty && x.initial == y.initial ||
        x.spelling.startsWith('y') && y.spelling.startsWith('y') ||
        x.spelling.startsWith('w') && y.spelling.startsWith('w')) {
      distance += 2.5;
    } else {
      return null;
    }
  }
  return distance;
}

enum SimilarSoundKind {
  syllable('Tones and meanings'),
  beginning('Same beginning'),
  ending('Same ending'),
  nearby('Nearby sounds');

  const SimilarSoundKind(this.label);
  final String label;
}

class SimilarSoundGroup {
  const SimilarSoundGroup(
    this.cards, {
    required this.kind,
    required this.label,
  });
  final List<StudyCard> cards;
  final SimilarSoundKind kind;
  final String label;
}

/// Different contrasts are separate groups. The same word intentionally appears
/// in more than one group; group membership is derived, never stored in the DB.
List<SimilarSoundGroup> similarSoundGroups(
  Iterable<StudyCard> cards, {
  bool includeEveryCategory = false,
}) {
  final indexed = <int, (StudyCard, List<PinyinSyllable>)>{};
  for (final card in cards) {
    if (!isChineseLanguage(card.language) ||
        card.learningStatus != LearningStatus.recall ||
        card.content is! LanguageCardContent) {
      continue;
    }
    final parsed = parsePinyin(
      (card.content as LanguageCardContent).transliteration,
    );
    if (parsed.isNotEmpty) indexed[card.id] = (card, parsed);
  }
  final result = <SimilarSoundGroup>[];
  final seen = <String>{};
  String base(int id) => indexed[id]!.$2.map((s) => s.spelling).join(' ');
  void add(SimilarSoundKind kind, List<StudyCard> members) {
    if (members.length < 2) return;
    final bases = members.map((c) => base(c.id)).toSet().toList()..sort();
    if (kind != SimilarSoundKind.syllable && bases.length < 2) return;
    members.sort((a, b) {
      final order = base(a.id).compareTo(base(b.id));
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    final ids = members.map((c) => c.id).toList()..sort();
    // Browsing tabs show every matching category. Recall still avoids asking
    // an identical set twice merely because two rules found it.
    final category = includeEveryCategory ? kind.name : '';
    if (!seen.add('$category:${ids.join(',')}')) return;
    result.add(
      SimilarSoundGroup(members, kind: kind, label: bases.join(' · ')),
    );
  }

  final same = <String, List<StudyCard>>{};
  final beginnings = <String, List<StudyCard>>{};
  final endings = <String, List<StudyCard>>{};
  for (final entry in indexed.values) {
    same.putIfAbsent(base(entry.$1.id), () => []).add(entry.$1);
    for (var i = 0; i < entry.$2.length; i++) {
      final syllable = entry.$2[i];
      final context = [
        for (var j = 0; j < entry.$2.length; j++)
          j == i ? '*' : entry.$2[j].spelling,
      ].join(' ');
      final initial = syllable.initial.isNotEmpty
          ? syllable.initial
          : syllable.spelling.startsWith('y')
          ? 'y'
          : syllable.spelling.startsWith('w')
          ? 'w'
          : '';
      if (initial.isNotEmpty) {
        beginnings.putIfAbsent('$context:$initial', () => []).add(entry.$1);
      }
      endings
          .putIfAbsent('$context:${syllable.finalSound}', () => [])
          .add(entry.$1);
    }
  }
  for (final members in same.values) {
    add(SimilarSoundKind.syllable, members);
  }
  // Narrow sound contrasts precede broader shared-initial/ending families.
  for (final seed in indexed.values) {
    final nearby = [
      for (final other in indexed.values)
        if (pinyinDistance(seed.$2, other.$2) case final distance?
            when distance <= 1.5)
          other.$1,
    ];
    add(SimilarSoundKind.nearby, nearby);
  }
  for (final members in beginnings.values) {
    add(SimilarSoundKind.beginning, members);
  }
  for (final members in endings.values) {
    add(SimilarSoundKind.ending, members);
  }
  return result;
}

class SimilarRecallGroup {
  const SimilarRecallGroup({
    required this.prompts,
    required this.comparisonCards,
    this.label = 'Similar sounds',
  });
  final List<StudyPrompt> prompts;
  final List<StudyCard> comparisonCards;
  final String label;
}

/// Rank groups by average retention in this direction. Comparisons retain the
/// full group even when the remaining question budget cuts a group short.
List<SimilarRecallGroup> similarSoundRecallGroups(
  List<StudyPrompt> candidates, {
  required int limit,
  Random? random,
}) {
  if (candidates.isEmpty || limit < 1) return [];
  final cue = candidates.first.cue;
  if (candidates.any((p) => p.cue != cue)) return [];
  final prompts = {for (final p in candidates) p.cardId: p};
  final groups = similarSoundGroups(prompts.values.map((p) => p.card));
  double score(SimilarSoundGroup g) =>
      g.cards.fold<double>(0, (sum, c) => sum + recallScore(c, cue).fraction) /
      g.cards.length;
  groups.sort((a, b) {
    final order = score(a).compareTo(score(b));
    return order != 0 ? order : a.cards.first.id.compareTo(b.cards.first.id);
  });
  final result = <SimilarRecallGroup>[];
  var left = limit;
  for (final group in groups) {
    if (left == 0) break;
    final questions = [for (final c in group.cards) prompts[c.id]!];
    questions.shuffle(random);
    final chosen = questions.take(left).toList();
    if (chosen.isEmpty) continue;
    result.add(
      SimilarRecallGroup(
        prompts: chosen,
        comparisonCards: group.cards,
        label: group.label,
      ),
    );
    left -= chosen.length;
  }
  return result;
}
