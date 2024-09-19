import json
import os
import time
import logging
import re
import requests
from typing import Any, Dict, List, Optional, Sequence, Tuple, Union


LIST_OF_COMMA_SEPARATED_URLS = ""

class BingSearchAPI():
    
    sites : str = None

    def __init__(self, bing_subscription_key: str, top_k: int = 5):
        self.bing_subscription_key = bing_subscription_key
        self.k = top_k
        self.bing_search_url = "https://api.bing.microsoft.com/v7.0/search"
        self.sites = None


    def _bing_search_results(self, search_term: str, count: int) -> List[dict]:
        
        headers = {"Ocp-Apim-Subscription-Key": self.bing_subscription_key}
        params = {
            "q": search_term,
            "count": count,
            "textDecorations": False,
            "textFormat": "Raw",
            "safeSearch": "Strict",
        }

        response = requests.get(
            self.bing_search_url, headers=headers, params=params  # type: ignore
        )
        response.raise_for_status()
        search_results = response.json()

        return search_results["webPages"]["value"]


    def search(self, query: str, count=None) -> str:
        """Run query through BingSearch and parse result."""

        if self.sites is None:
            self.sites = ""
            arr = LIST_OF_COMMA_SEPARATED_URLS.split(",")
            if len(arr) > 0:
                sites_v = ["site:"+site.strip() for site in arr]
                sites_v = " OR ".join(sites_v)
                sites_v = f"({sites_v})"
                self.sites = sites_v

            # print("Sites", self.sites)

        if count: self.k = count

        snippets = []
        try:
            results = self._bing_search_results(f"{self.sites} {query}", count=self.k)
        except Exception as e:
            print("Error in bing search", e)
            return snippets

        if len(results) == 0:
            return "No good Bing Search Result was found"
        for result in results:
            snippets.append('['+result["url"] + '] ' + result["snippet"])
        
        print(f"Snippets for {query}:\n", "\n".join(snippets), "\n")

        return snippets