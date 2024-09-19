from tavily import TavilyClient
from firecrawl import FirecrawlApp



class WebDataRetriever:
    """
    A class that integrates Tavily and FireCrawl for web search and web scraping functionalities.
    """

    def __init__(self, tavily_api_key, firecrawl_api_key):
        """
        Initialize the WebDataRetriever with API keys for Tavily and FireCrawl.

        :param tavily_api_key: API key for Tavily.
        :param firecrawl_api_key: API key for FireCrawl.
        """
        self.tavily_client = TavilyClient(api_key=tavily_api_key)
        self.firecrawl_app = FirecrawlApp(api_key=firecrawl_api_key)

    def search_with_tavily(self, query):
        """
        Perform a web search using Tavily.

        :param query: The search query string.
        :return: The response from Tavily API.
        """
        try:
            response = self.tavily_client.search(query)
            return response
        except Exception as e:
            print(f"An error occurred during Tavily search: {e}")
            return None

    def scrape_with_firecrawl(self, url, formats=['markdown', 'html']):
        """
        Scrape a single webpage using FireCrawl.

        :param url: The URL of the webpage to scrape.
        :param formats: A list of formats to retrieve ('markdown', 'html', etc.).
        :return: The response from FireCrawl API.
        """
        try:
            response = self.firecrawl_app.scrape_url(url, params={'formats': formats})
            return response
        except Exception as e:
            print(f"An error occurred during FireCrawl scrape: {e}")
            return None

    def crawl_with_firecrawl(self, url, limit=10, formats=['markdown', 'html']):
        """
        Crawl a website and scrape multiple pages using FireCrawl.

        :param url: The base URL to start crawling from.
        :param limit: The maximum number of pages to crawl.
        :param formats: A list of formats to retrieve ('markdown', 'html', etc.).
        :return: The response from FireCrawl API.
        """
        try:
            response = self.firecrawl_app.crawl_url(
                url,
                params={
                    'limit': limit,
                    'scrapeOptions': {'formats': formats}
                }
            )
            return response
        except Exception as e:
            print(f"An error occurred during FireCrawl crawl: {e}")
            return None
