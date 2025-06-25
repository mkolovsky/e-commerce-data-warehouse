🌟 **Star Schema Data Warehouse: ETL & BI Project for Basket Craft**

📌 **Overview**
This project demonstrates how to build a scalable data warehouse using the Star Schema model. It integrates data from multiple sources—including CSV files and remote MySQL databases—using Python, Tableau Prep, and Alteryx. The final warehouse supports fast, flexible business intelligence with dashboards in Tableau and Power BI.

🎯 **Objective**
To design and implement a dimensional model that:
• Consolidates data from diverse sources into a single analytical database
• Enables slicing-and-dicing of data across dimensions like time, product, and customer
• Supports strategic, operational, and analytical decision-making with efficient queries and visualizations

🛠️ **Tools & Technologies**
• ETL Tools: Python, Alteryx, Tableau Prep
• Database: MySQL (LMU Build)
• BI Tools: Tableau, Power BI
• Others: Excel (for date dimension), Draw\.io (for schema diagram)

📂 **Data Sources**
• `website_pageviews.csv` – Large CSV file (1M+ rows)
• LMU Build: `kcslmubu_basket_craft_orders` – includes `orders`, `order_items`, `users`
• Aiven Cloud DB: `basket_craft_partial` – includes `products`
• db.isba.co: `basket_craft` – includes `order_item_refunds`, `website_sessions`

📐 **Data Warehouse Design**

**Fact Tables**
• `fact_sales` – Non-returned sales transactions
• `fact_returns` – Returned item transactions

**Dimension Tables**
• `dim_date` – Date hierarchy (day, week, month, quarter, year)
• `dim_product` – Product metadata
• `dim_user` – Customer metadata
• `dim_landing_page` – Derived from session/pageview data

**Grain**: Daily-level grain by product, user, and session

📊 **Sample Business Questions**

Strategic
• What is the year-over-year revenue growth by region?
• What is the average revenue by product line per quarter?

Operational
• What are the top 2 most returned products this month?
• How many returns occurred by day of the week in June 2024?

Analytical
• Do mobile users purchase different products than desktop users?
• Which UTM campaigns result in the most orders?

Each question is answered using SQL queries and visualized in Tableau or Power BI dashboards.

🧪 **ETL Approach**

**Python**
• Load `website_pageviews.csv`
• Aggregate and populate `fact_sales` and `fact_returns`
• Validate data types and schema

**Tableau Prep / Alteryx**
• Load and clean `products` and `users` tables
• Join sessions and pageviews to create `dim_landing_page`
• Create `dim_product`, `dim_user`, and `dim_date` tables

🖼️ **Visualizations**
Dashboards were built in Tableau to support business insight generation:
• Revenue trends over time
• Campaign and device performance
• Return patterns by product and user

📁 **Project Files**

• star\_schema\_details.xlsx – Fact and dimension definitions
• data\_warehouse\_erd.jpg – Star schema diagram
• assignment\_2.sql – All SQL queries used
• Tableau dashboard (.twbx)
• Python notebooks for ETL
• Alteryx and Tableau Prep flows
• Sample data files

🚀 **Impact**
This project showcases the end-to-end development of a robust data warehouse that:
• Handles millions of records across multiple systems
• Supports rapid query performance for BI tools
• Enables actionable decision-making for strategic growth

