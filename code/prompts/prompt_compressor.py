from llmlingua import PromptCompressor

prompt = """
Give me a business overview of the company and generate a detailed summary of its contents. Focus on the following elements:

##Grounding:

#Company Overview: Summarize the company's background, market entry, and operational highlights. Please  use bullet points to highlight key information.
#Key Financials: Extract and interpret financial data, such as revenue, EBITDA, and margins over a specified period.
#Sales Segmentation: Break down the sales data by customer segment and sales channel.
#Distribution Network: Detail the distribution channels and the number of outlets.

## Self-evaluation: 

Evaluate or check your own responses before producing them: ​

    # Think step by step 
    # Make sure to limit your response to few sentences, ​
    # Rate your work on a scale of 1-10 for conciseness, ​
    # Do you think that you are correct?

Below is an example: 
## START OF EXAMPLE

*Title and Heading: mention the company name

*The heading states that "Pepe Jeans is the #2 casual wear brand in India with FY19 revenue and adj. EBITDA of $75m and $14m".
*Company Overview Section:
*Pepe Jeans is a European brand with operations in 70 countries and revenue of €382m.
*It entered the Indian market in 1989, and its Indian operations account for approximately 17% of global sales.
*Pepe India operates under a perpetual license.
*It is positioned as the second top casual wear brand in India and in the premium segment of the market.
*The company operates under two brands: Pepe Jeans London and Beat London, the latter being a value sub-brand introduced in the second half of FY19.
*Key Financials Chart:

There is a chart showing the Revenue and EBITDA from FY15 to FY19, with revenue showing a compound annual growth rate (CAGR) of 25%.
EBITDA margins are listed for each year, with a noted decline over the five-year period.
*Sales by Segment and Channel (FY18):
Two pie charts display the sales by segment and channel for FY18.
The first pie chart details the percentage of sales by customer segment: Men (80%), Women (11%), and Kids (9%).
The second pie chart illustrates sales by channel: E-commerce and Others (11%), Off Price Doors (7%), LFS Doors (30%), and Franchisee Company Owned Stores, Franchisee SOR (7%).
*Distribution Channel and Number of Outlets:

A table lists the distribution channels along with the number of outlets. It shows a total of 2,101 outlets, with the majority being LFS (420) and Distribution (MBO/Franchisee OR) with 1,532 outlets. Other channels include Franchisee SOR, Company Owned Stores, and Off Price with fewer outlets.
## END OF EXAMPLE


"""
llm_lingua = PromptCompressor()
compressed_prompt = llm_lingua.compress_prompt(
    prompt, instruction="", question="", target_token=200
)

print(compressed_prompt)
