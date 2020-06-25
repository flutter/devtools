import 'package:devtools_app/src/navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('routeNameWithQueryParams', () {
    test('Generates a route name with params without a context', () {
      expect(routeNameWithQueryParams(null, '/'), '/');
      expect(routeNameWithQueryParams(null, '/home'), '/home');
      expect(routeNameWithQueryParams(null, '/', {}), '/?');
      expect(routeNameWithQueryParams(null, '/', {'foo': 'bar'}), '/?foo=bar');
      expect(
          routeNameWithQueryParams(null, '/', {'foo': 'bar', 'theme': 'dark'}),
          '/?foo=bar&theme=dark');
    });

    /// Builds an app that calls [onBuild] when [initialRoute] loads.
    Widget routeTestingApp(void Function(BuildContext) onBuild,
        {String initialRoute = '/'}) {
      return MaterialApp(
        initialRoute: initialRoute,
        routes: {
          initialRoute: (context) {
            onBuild(context);
            return const SizedBox();
          }
        },
      );
    }

    testWidgets(
        'Generates a route name with parameters with an empty route in the context',
        (WidgetTester tester) async {
      String generatedRoute;
      await tester.pumpWidget(
        routeTestingApp((context) {
          generatedRoute = routeNameWithQueryParams(
              context, '/home', {'foo': 'bar', 'theme': 'dark'});
        }),
      );
      expect(generatedRoute, '/home?foo=bar&theme=dark');
    });

    testWidgets('Respects dark theme of the current route from the context',
        (WidgetTester tester) async {
      String generatedRoute;
      await tester.pumpWidget(
        routeTestingApp((context) {
          generatedRoute =
              routeNameWithQueryParams(context, '/home', {'foo': 'bar'});
        }, initialRoute: '/?theme=dark'),
      );
      expect(generatedRoute, '/home?foo=bar&theme=dark');
    });

    testWidgets(
        'Removes redundant light theme of the current route from the context',
        (WidgetTester tester) async {
      String generatedRoute;
      await tester.pumpWidget(
        routeTestingApp((context) {
          generatedRoute =
              routeNameWithQueryParams(context, '/home', {'foo': 'bar'});
        }, initialRoute: '/?theme=light'),
      );
      expect(generatedRoute, '/home?foo=bar');
    });

    testWidgets(
        'Overrides dark theme of the current route when a replacement theme is given',
        (WidgetTester tester) async {
      String generatedRoute;
      await tester.pumpWidget(
        routeTestingApp((context) {
          generatedRoute = routeNameWithQueryParams(
              context, '/home', {'foo': 'bar', 'theme': 'light'});
        }, initialRoute: '/?snap=crackle&theme=dark'),
      );
      expect(generatedRoute, '/home?foo=bar&theme=light');
    });

    testWidgets(
        'Overrides other parameters of the current route from the context',
        (WidgetTester tester) async {
      String generatedRoute;
      await tester.pumpWidget(
        routeTestingApp((context) {
          generatedRoute =
              routeNameWithQueryParams(context, '/home', {'foo': 'baz'});
        }, initialRoute: '/?foo=bar&baz=quux'),
      );
      expect(generatedRoute, '/home?foo=baz');
    });

    group('in an unnamed route', () {
      // TODO(jacobr): rewrite these tests in a way that makes sense given how
      // we are now managing the dark and light themes.
/*
      /// Builds an app that loads an unnamed route and calls [onBuild] when
      /// the unnamed route loads.
      Widget unnamedRouteApp(void Function(BuildContext) onUnnamedRouteBuild) {
        return routeTestingApp((context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (innerContext) {
              onUnnamedRouteBuild(innerContext);
              return const SizedBox();
            }));
          });
        });
      }

      testWidgets('Builds with global dark mode when dark mode is on',
          (WidgetTester tester) async {
        String generatedRoute;
        // ignore: deprecated_member_use_from_same_package
        setTheme(darkTheme: true);
        await tester.pumpWidget(unnamedRouteApp((context) {
          generatedRoute =
              routeNameWithQueryParams(context, '/home', {'foo': 'baz'});
        }));
        await tester.pumpAndSettle();
        expect(generatedRoute, '/home?foo=baz&theme=dark');
        // Teardown the global theme change
        // ignore: deprecated_member_use_from_same_package
        setTheme(darkTheme: false);
      });

      testWidgets('Builds with global light mode when dark mode is off',
          (WidgetTester tester) async {
        String generatedRoute;
        await tester.pumpWidget(unnamedRouteApp((context) {
          generatedRoute =
              routeNameWithQueryParams(context, '/home', {'foo': 'baz'});
        }));
        await tester.pumpAndSettle();
        expect(generatedRoute, '/home?foo=baz');
      });

 */
    });
  });
}
