import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Button, Card, Form, Input, Typography, message } from 'antd';
import { Link, useNavigate } from 'react-router-dom';
import { login } from '../../api/auth';
import { useAuth } from '../../app/providers/AuthProvider';

const schema = z.object({
  email: z.string().email('Enter a valid email'),
  password: z.string().min(1, 'Password is required'),
});

type FormData = z.infer<typeof schema>;

export function LoginPage() {
  const navigate = useNavigate();
  const { setUser } = useAuth();
  const { register, handleSubmit, formState: { errors, isSubmitting } } = useForm<FormData>({
    resolver: zodResolver(schema),
  });

  const onSubmit = async (data: FormData) => {
    try {
      const response = await login(data.email, data.password);
      setUser(response);
      message.success('Welcome back!');
      navigate('/');
    } catch {
      message.error('Invalid email or password');
    }
  };

  return (
    <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#f5f5f5' }}>
      <Card style={{ width: 400 }}>
        <Typography.Title level={3}>PostInTime</Typography.Title>
        <Typography.Paragraph type="secondary">Sign in to your account</Typography.Paragraph>
        <form onSubmit={handleSubmit(onSubmit)}>
          <Form.Item label="Email" validateStatus={errors.email ? 'error' : ''} help={errors.email?.message}>
            <Input {...register('email')} type="email" placeholder="you@example.com" />
          </Form.Item>
          <Form.Item label="Password" validateStatus={errors.password ? 'error' : ''} help={errors.password?.message}>
            <Input.Password {...register('password')} placeholder="Password" />
          </Form.Item>
          <Button type="primary" htmlType="submit" block loading={isSubmitting}>Sign In</Button>
        </form>
        <Typography.Paragraph style={{ marginTop: 16 }}>
          No account? <Link to="/register">Register</Link>
        </Typography.Paragraph>
      </Card>
    </div>
  );
}
