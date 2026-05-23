import { Routes, Route, Navigate } from 'react-router-dom';
import { lazy, Suspense } from 'react';
import { Layout } from '@/components/Layout';
import { ProtectedRoute } from '@/components/ProtectedRoute';
import Landing from '@/pages/Landing';
import Login from '@/pages/Login';

const AuthCallback = lazy(() => import('@/pages/AuthCallback'));
const Pricing = lazy(() => import('@/pages/Pricing'));
const CheckoutSuccess = lazy(() => import('@/pages/CheckoutSuccess'));
const Dashboard = lazy(() => import('@/pages/Dashboard'));
const ProductsList = lazy(() => import('@/pages/ProductsList'));
const AddProduct = lazy(() => import('@/pages/AddProduct'));
const EditProduct = lazy(() => import('@/pages/EditProduct'));
const Culprits = lazy(() => import('@/pages/Culprits'));
const Scanner = lazy(() => import('@/pages/Scanner'));
const Settings = lazy(() => import('@/pages/Settings'));
const Routine = lazy(() => import('@/pages/Routine'));
const Recommend = lazy(() => import('@/pages/Recommend'));
const Journal = lazy(() => import('@/pages/Journal'));
const Roadmap = lazy(() => import('@/pages/Roadmap'));

function RouteFallback() {
  return (
    <div className="min-h-[60vh] flex items-center justify-center">
      <div className="size-6 rounded-full border-2 border-primary/20 border-t-primary animate-spin" />
    </div>
  );
}

function App() {
  return (
    <Suspense fallback={<RouteFallback />}>
      <Routes>
        <Route path="/" element={<Landing />} />
        <Route path="/login" element={<Login />} />
        <Route path="/auth/callback" element={<AuthCallback />} />
        <Route path="/pricing" element={<Pricing />} />
        <Route path="/checkout/success" element={<CheckoutSuccess />} />
        <Route path="/roadmap" element={<Roadmap />} />

        <Route
          path="/app"
          element={
            <ProtectedRoute>
              <Layout>
                <Dashboard />
              </Layout>
            </ProtectedRoute>
          }
        />
        <Route
          path="/app/products"
          element={
            <ProtectedRoute>
              <Layout>
                <ProductsList />
              </Layout>
            </ProtectedRoute>
          }
        />
        <Route
          path="/app/products/new"
          element={
            <ProtectedRoute>
              <Layout>
                <AddProduct />
              </Layout>
            </ProtectedRoute>
          }
        />
        <Route
          path="/app/products/:id"
          element={
            <ProtectedRoute>
              <Layout>
                <EditProduct />
              </Layout>
            </ProtectedRoute>
          }
        />
        <Route
          path="/app/culprits"
          element={
            <ProtectedRoute>
              <Layout>
                <Culprits />
              </Layout>
            </ProtectedRoute>
          }
        />
        <Route
          path="/app/scanner"
          element={
            <ProtectedRoute>
              <Layout>
                <Scanner />
              </Layout>
            </ProtectedRoute>
          }
        />
        <Route
          path="/app/settings"
          element={
            <ProtectedRoute>
              <Layout>
                <Settings />
              </Layout>
            </ProtectedRoute>
          }
        />
        <Route
          path="/app/routine"
          element={
            <ProtectedRoute>
              <Layout>
                <Routine />
              </Layout>
            </ProtectedRoute>
          }
        />
        <Route
          path="/app/recommend"
          element={
            <ProtectedRoute>
              <Layout>
                <Recommend />
              </Layout>
            </ProtectedRoute>
          }
        />
        <Route
          path="/app/journal"
          element={
            <ProtectedRoute>
              <Layout>
                <Journal />
              </Layout>
            </ProtectedRoute>
          }
        />

        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </Suspense>
  );
}

export default App;
