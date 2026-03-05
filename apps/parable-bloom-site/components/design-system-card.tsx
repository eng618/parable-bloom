'use client';

import { Button, Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle, Text } from '@gv-tech/ui-web';
import Link from 'next/link';

type DesignSystemCardProps = {
  title: string;
  body: string;
  marker: string;
  href?: string;
  ctaLabel?: string;
};

export default function DesignSystemCard({ title, body, marker, href, ctaLabel = 'Open' }: DesignSystemCardProps) {
  return (
    <Card className="card">
      <CardHeader>
        <CardTitle>
          {marker} {title}
        </CardTitle>
      </CardHeader>

      <CardContent className="card-content">
        <CardDescription>
          <Text variant="body">{body}</Text>
        </CardDescription>
      </CardContent>

      <CardFooter>
        {href ? (
          <Button asChild className="w-full">
            <Link href={href}>{ctaLabel}</Link>
          </Button>
        ) : (
          <Button disabled className="w-full">
            {ctaLabel}
          </Button>
        )}
      </CardFooter>
    </Card>
  );
}
