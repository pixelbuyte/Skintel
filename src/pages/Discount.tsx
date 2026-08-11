import { Navigate } from 'react-router-dom';

/**
 * The founding-member offer this page was built around is retired ahead of
 * launch. Redirecting rather than deleting the route keeps any existing
 * /discount links (emails, social posts) from 404ing.
 */
export default function Discount() {
  return <Navigate to="/pricing" replace />;
}
