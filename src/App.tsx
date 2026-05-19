import { Routes, Route, Navigate } from 'react-router-dom';
import { Layout } from '@/components/Layout';
import { ProtectedRoute } from '@/components/ProtectedRoute';
import Landing from '@/pages/Landing';
import Login from '@/pages/Login';
import AuthCallback from '@/pages/AuthCallback';
import Pricing from '@/pages/Pricing';
import CheckoutSuccess from '@/pages/CheckoutSuccess';
import Dashboard from '@/pages/Dashboard';
import ProductsList from '@/pages/ProductsList';
import AddProduct from '@/pages/AddProduct';
import EditProduct from '@/pages/EditProduct';
import Culprits from '@/pages/Culprits';
import Scanner from '@/pages/Scanner';
import Settings from '@/pages/Settings';

function App() {
  return (
    <Routes>
      <Route path="/" element={<Landing />} />
      <Route path="/login" element={<Login />} />
      <Route path="/auth/callback" element={<AuthCallback />} />
      <Route path="/pricing" element={<Pricing />} />
      <Route path="/checkout/success" element={<CheckoutSuccess />} />

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

      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

export default App;
