extension UriExtensions on Uri {
  Uri appendPathSegments(List<String> segmentsToAppend) {
    return Uri(
      scheme: hasScheme ? scheme : null,
      host: host,
      port: hasPort ? port : null,
      pathSegments: [...pathSegments, ...segmentsToAppend],
      query: hasQuery ? query : null,
      fragment: hasFragment ? fragment : null,
    );
  }
}
