class NewsItem {
  final String? id;
  final String? primaryTicker;
  final String? publisherTicker;
  final List<String>? relatedTickers;
  final PublishedAt? publishedAt;
  final String? category;
  final double newsworthiness;
  final String? headline;
  final List<Fact>? facts;
  final String? visualPrompt;
  final String? url;
  final String? ticker;
  final Seo? seo;
  final Tweet? tweet;

  NewsItem({
    this.id,
    this.primaryTicker,
    this.publisherTicker,
    this.relatedTickers,
    this.publishedAt,
    this.category,
    this.newsworthiness = 0.0,
    this.headline,
    this.facts,
    this.visualPrompt,
    this.url,
    this.ticker,
    this.seo,
    this.tweet,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      id: json['id'] ?? json['_id'],
      primaryTicker: json['primaryTicker'] ?? json['primary_ticker'],
      publisherTicker: json['publisherTicker'] ?? json['publisher_ticker'],
      relatedTickers: (json['relatedTickers'] ?? json['related_tickers']) != null
          ? List<String>.from(json['relatedTickers'] ?? json['related_tickers'])
          : null,
      publishedAt: (json['publishedAt'] ?? json['published_at']) != null
          ? PublishedAt.fromJson(json['publishedAt'] ?? json['published_at'])
          : null,
      category: json['category'],
      newsworthiness: (json['newsworthiness'] ?? 0).toDouble(),
      headline: json['headline'],
      facts: json['facts'] != null
          ? (json['facts'] as List).map((f) => Fact.fromJson(f)).toList()
          : null,
      visualPrompt: json['visualPrompt'] ?? json['visual_prompt'],
      url: json['url'],
      ticker: json['ticker'],
      seo: json['seo'] != null ? Seo.fromJson(json['seo']) : null,
      tweet: json['tweet'] != null ? Tweet.fromJson(json['tweet']) : null,
    );
  }

  String get displayTicker => primaryTicker ?? ticker ?? 'N/A';
  
  String get displayTime {
    if (publishedAt?.time != null) {
      return publishedAt!.time!.substring(0, 5);
    }
    return '';
  }
  
  String get description {
    // Kullanıcı isteği üzerine öncelikle tweet text'ini gösteriyoruz
    if (tweet?.text != null && tweet!.text!.isNotEmpty) {
      return tweet!.text!;
    }
    if (seo?.articleMd != null && seo!.articleMd!.isNotEmpty) {
      return seo!.articleMd!;
    }
    return '';
  }

  String get summary {
    if (facts != null && facts!.isNotEmpty) {
      final validFacts = facts!
          .where((f) => f.value != null && f.value!.isNotEmpty)
          .take(2)
          .map((f) => f.value!)
          .toList();
      return validFacts.join(' ');
    }
    return '';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'primaryTicker': primaryTicker,
      'publisherTicker': publisherTicker,
      'relatedTickers': relatedTickers,
      'publishedAt': publishedAt != null ? {
        'date': publishedAt!.date,
        'time': publishedAt!.time,
        'timezone': publishedAt!.timezone,
      } : null,
      'category': category,
      'newsworthiness': newsworthiness,
      'headline': headline,
      'facts': facts?.map((f) => {'k': f.key, 'v': f.value}).toList(),
      'visualPrompt': visualPrompt,
      'url': url,
      'ticker': ticker,
      'seo': seo != null ? {
        'title': seo!.title,
        'meta_description': seo!.metaDescription,
        'article_md': seo!.articleMd,
      } : null,
      'tweet': tweet != null ? {
        'text': tweet!.text,
        'hashtags': tweet!.hashtags,
        'disclaimer': tweet!.disclaimer,
      } : null,
    };
  }
}

class PublishedAt {
  final String? date;
  final String? time;
  final String? timezone;

  PublishedAt({this.date, this.time, this.timezone});

  factory PublishedAt.fromJson(Map<String, dynamic> json) {
    return PublishedAt(
      date: json['date'],
      time: json['time'],
      timezone: json['timezone'],
    );
  }
}

class Fact {
  final String? key;
  final String? value;

  Fact({this.key, this.value});

  factory Fact.fromJson(Map<String, dynamic> json) {
    return Fact(
      key: json['key'] ?? json['k'],
      value: json['value'] ?? json['v'],
    );
  }
}

class Seo {
  final String? title;
  final String? metaDescription;
  final String? articleMd;

  Seo({this.title, this.metaDescription, this.articleMd});

  factory Seo.fromJson(Map<String, dynamic> json) {
    return Seo(
      title: json['title'],
      metaDescription: json['metaDescription'] ?? json['meta_description'],
      articleMd: json['articleMd'] ?? json['article_md'],
    );
  }
}

class Tweet {
  final String? text;
  final List<String>? hashtags;
  final String? disclaimer;

  Tweet({this.text, this.hashtags, this.disclaimer});

  factory Tweet.fromJson(Map<String, dynamic> json) {
    return Tweet(
      text: json['text'],
      hashtags: json['hashtags'] != null ? List<String>.from(json['hashtags']) : null,
      disclaimer: json['disclaimer'],
    );
  }
}
