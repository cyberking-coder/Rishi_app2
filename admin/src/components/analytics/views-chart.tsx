"use client";

import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

export interface DailyPoint {
  day: string;
  views: number;
  watchHours: number;
}

export function ViewsChart({ data }: { data: DailyPoint[] }) {
  return (
    <ResponsiveContainer width="100%" height={300}>
      <AreaChart data={data} margin={{ top: 8, right: 8, left: -16, bottom: 0 }}>
        <defs>
          <linearGradient id="views" x1="0" y1="0" x2="0" y2="1">
            <stop offset="5%" stopColor="hsl(346 77% 49%)" stopOpacity={0.5} />
            <stop offset="95%" stopColor="hsl(346 77% 49%)" stopOpacity={0} />
          </linearGradient>
        </defs>
        <CartesianGrid strokeDasharray="3 3" stroke="hsl(240 3.7% 15.9%)" />
        <XAxis
          dataKey="day"
          tick={{ fill: "hsl(240 5% 64.9%)", fontSize: 12 }}
          tickLine={false}
          axisLine={false}
        />
        <YAxis
          tick={{ fill: "hsl(240 5% 64.9%)", fontSize: 12 }}
          tickLine={false}
          axisLine={false}
        />
        <Tooltip
          contentStyle={{
            background: "hsl(240 10% 5.9%)",
            border: "1px solid hsl(240 3.7% 15.9%)",
            borderRadius: 8,
            color: "hsl(0 0% 98%)",
          }}
        />
        <Area
          type="monotone"
          dataKey="views"
          name="Views"
          stroke="hsl(346 77% 49%)"
          fill="url(#views)"
          strokeWidth={2}
        />
      </AreaChart>
    </ResponsiveContainer>
  );
}
