import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns


def run_food_delivery_analysis(filepath: str = "data/food_delivery_orders.csv"):
    """Load food delivery logs and generate operational KPIs, SLA metrics, and charts."""
    df = pd.read_csv(filepath)

    total_orders = len(df)
    delivered = df[df["Order_Status"] == "Delivered"].copy()
    cancelled = df[df["Order_Status"] == "Cancelled"].copy()

    cancel_rate = len(cancelled) / total_orders * 100
    avg_delivery = delivered["Delivery_Time_Mins"].mean()
    sla_compliance = (delivered["Delivery_Time_Mins"] <= 40).mean() * 100
    avg_rating = delivered["Customer_Rating"].mean()
    net_gmv = delivered["Order_Value_INR"].sum()
    lost_gmv = cancelled["Order_Value_INR"].sum()

    print("=" * 60)
    print("FOOD DELIVERY OPERATIONS SUMMARY (OCTOBER 2026)")
    print("=" * 60)
    print(f"Total Orders Placed     : {total_orders:,}")
    print(f"Delivered Orders        : {len(delivered):,} ({100 - cancel_rate:.1f}%)")
    print(f"Cancelled Orders        : {len(cancelled):,} ({cancel_rate:.2f}%)")
    print(f"Net Delivered GMV       : INR {net_gmv:,.2f}")
    print(f"Lost GMV (Cancellations): INR {lost_gmv:,.2f}")
    print(f"Avg Delivery Time       : {avg_delivery:.1f} mins (Target SLA <= 40 mins)")
    print(f"On-Time SLA Compliance  : {sla_compliance:.1f}%")
    print(f"Avg Customer Rating     : {avg_rating:.2f} / 5.00")
    print("=" * 60)

    # City-wise breakdown
    city_kpi = df.groupby("City").agg(
        Orders=("Order_ID", "count"),
        Cancel_Rate_Pct=("Order_Status", lambda x: (x == "Cancelled").mean() * 100),
        Avg_Delivery_Mins=("Delivery_Time_Mins", "mean"),
        Avg_Rating=("Customer_Rating", "mean"),
        Net_GMV_INR=("Order_Value_INR", lambda s: s[df.loc[s.index, "Order_Status"] == "Delivered"].sum())
    ).round(2).sort_values("Net_GMV_INR", ascending=False)

    print("\nCity-Level Performance:\n", city_kpi)

    # Cancellation breakdown
    print("\nCancellation Reasons:\n", cancelled["Cancellation_Reason"].value_counts(normalize=True).mul(100).round(1))


if __name__ == "__main__":
    run_food_delivery_analysis()
