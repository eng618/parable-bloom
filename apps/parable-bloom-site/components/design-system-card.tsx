import { Card, CardContent, CardHeader, CardTitle } from "@gv-tech/ui-web";

type DesignSystemCardProps = {
  title: string;
  body: string;
  marker: string;
};

export default function DesignSystemCard({ title, body, marker }: DesignSystemCardProps) {
  return (
    <Card className="card">
      <CardHeader>
        <CardTitle>{marker} {title}</CardTitle>
      </CardHeader>
      <CardContent>
        <p>{body}</p>
      </CardContent>
    </Card>
  );
}
