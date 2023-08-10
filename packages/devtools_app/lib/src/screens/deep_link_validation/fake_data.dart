import 'deep_links_model.dart';

const paths = <String>[
  '/shoes/..*',
  '/Clothes/..*',
  '/Toys/..*',
  '/Jewelry/..*',
  '/Watches/..* ',
  '/Glasses/..*',
];

final allLinkDatas = <LinkData>[
  for (var path in paths)
    LinkData(
      os: 'Android, iOS',
      domain: 'm.shopping.com',
      paths: [path],
      domainError: true,
      pathError: path.contains('shoe'),
    ),
  for (var path in paths)
    LinkData(
      os: 'iOS',
      domain: 'm.french.shopping.com',
      paths: [path],
      pathError: path.contains('shoe'),
    ),
  for (var path in paths)
    LinkData(
      os: 'Android',
      domain: 'm.chinese.shopping.com',
      paths: [path],
      pathError: path.contains('shoe'),
    ),
];
