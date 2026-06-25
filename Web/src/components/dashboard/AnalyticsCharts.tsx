import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Legend,
  Line,
  LineChart,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import type {
  MonthlyMoneyPoint,
  StatusSlice,
  RatingPoint,
  RatingBar,
} from '@/lib/dashboardAnalytics';

const DONUT_COLORS = ['#6366f1', '#22c55e', '#f59e0b', '#ef4444', '#8b5cf6', '#06b6d4', '#64748b'];

function EmptyState({ label }: { label: string }) {
  return <div className="flex h-[240px] items-center justify-center text-sm text-muted-foreground">{label}</div>;
}

export function MoneyFlowChart({ data }: { data: MonthlyMoneyPoint[] }) {
  return (
    <Card>
      <CardHeader><CardTitle>Earnings & spending</CardTitle></CardHeader>
      <CardContent>
        {data.length === 0 ? (
          <EmptyState label="No completed deals yet" />
        ) : (
          <ResponsiveContainer width="100%" height={240}>
            <BarChart data={data}>
              <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
              <XAxis dataKey="label" fontSize={12} />
              <YAxis fontSize={12} />
              <Tooltip formatter={(v: number) => `৳${Math.round(v).toLocaleString()}`} />
              <Legend />
              <Bar dataKey="earned" name="Earned" fill="#22c55e" radius={[4, 4, 0, 0]} />
              <Bar dataKey="spent" name="Spent" fill="#6366f1" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        )}
      </CardContent>
    </Card>
  );
}

export function StatusDonut({ data }: { data: StatusSlice[] }) {
  return (
    <Card>
      <CardHeader><CardTitle>Deals by status</CardTitle></CardHeader>
      <CardContent>
        {data.length === 0 ? (
          <EmptyState label="No deals yet" />
        ) : (
          <ResponsiveContainer width="100%" height={240}>
            <PieChart>
              <Pie data={data} dataKey="count" nameKey="status" innerRadius={55} outerRadius={90} paddingAngle={2}>
                {data.map((_, i) => (
                  <Cell key={i} fill={DONUT_COLORS[i % DONUT_COLORS.length]} />
                ))}
              </Pie>
              <Tooltip />
              <Legend />
            </PieChart>
          </ResponsiveContainer>
        )}
      </CardContent>
    </Card>
  );
}

export function RatingTrendChart({ data }: { data: RatingPoint[] }) {
  return (
    <Card>
      <CardHeader><CardTitle>Rating over time</CardTitle></CardHeader>
      <CardContent>
        {data.length === 0 ? (
          <EmptyState label="No reviews yet" />
        ) : (
          <ResponsiveContainer width="100%" height={240}>
            <LineChart data={data}>
              <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
              <XAxis dataKey="label" fontSize={12} />
              <YAxis domain={[0, 5]} fontSize={12} />
              <Tooltip formatter={(v: number) => v.toFixed(2)} />
              <Line type="monotone" dataKey="runningAverage" name="Avg rating" stroke="#f59e0b" strokeWidth={2} dot />
            </LineChart>
          </ResponsiveContainer>
        )}
      </CardContent>
    </Card>
  );
}

export function RatingDistributionChart({ data }: { data: RatingBar[] }) {
  const total = data.reduce((s, b) => s + b.count, 0);
  return (
    <Card>
      <CardHeader><CardTitle>Rating distribution</CardTitle></CardHeader>
      <CardContent>
        {total === 0 ? (
          <EmptyState label="No reviews yet" />
        ) : (
          <ResponsiveContainer width="100%" height={240}>
            <BarChart data={data} layout="vertical">
              <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
              <XAxis type="number" allowDecimals={false} fontSize={12} />
              <YAxis type="category" dataKey="stars" tickFormatter={(s) => `${s}★`} fontSize={12} />
              <Tooltip />
              <Bar dataKey="count" name="Reviews" fill="#f59e0b" radius={[0, 4, 4, 0]} />
            </BarChart>
          </ResponsiveContainer>
        )}
      </CardContent>
    </Card>
  );
}
