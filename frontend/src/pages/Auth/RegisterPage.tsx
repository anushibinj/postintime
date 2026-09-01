import { Controller, useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Button, Card, Form, Input, Typography, message } from 'antd';
import { Link, useNavigate } from 'react-router-dom';
import { register as registerUser } from '../../api/auth';
import { useAuth } from '../../app/providers/AuthProvider';

const schema = z.object({
  email: z.string().email('Enter a valid email'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  displayName: z.string().optional(),
});

type FormData = z.infer<typeof schema>;

export function RegisterPage() {
  const navigate = useNavigate();
  const { setUser } = useAuth();
  const { control, handleSubmit, formState: { errors, isSubmitting } } = useForm<FormData>({
    resolver: zodResolver(schema),
    defaultValues: { email: '', password: '', displayName: '' },
  });

  const onSubmit = async (data: FormData) => {
    try {
      const response = await registerUser(data.email, data.password, data.displayName);
      setUser(response);
      message.success('Account created!');
      navigate('/');
    } catch {
      message.error('Registration failed. Email may already be in use.');
    }
  };

  return (
    <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#f5f5f5' }}>
      <Card style={{ width: 400 }}>
        <Typography.Title level={3}>Create Account</Typography.Title>
        <form onSubmit={handleSubmit(onSubmit)}>
          <Form.Item label="Display Name" validateStatus={errors.displayName ? 'error' : ''} help={errors.displayName?.message}>
            <Controller
              name="displayName"
              control={control}
              render={({ field }) => <Input {...field} placeholder="Your name" />}
            />
          </Form.Item>
          <Form.Item label="Email" validateStatus={errors.email ? 'error' : ''} help={errors.email?.message}>
            <Controller
              name="email"
              control={control}
              render={({ field }) => <Input {...field} type="email" placeholder="you@example.com" />}
            />
          </Form.Item>
          <Form.Item label="Password" validateStatus={errors.password ? 'error' : ''} help={errors.password?.message}>
            <Controller
              name="password"
              control={control}
              render={({ field }) => <Input.Password {...field} placeholder="At least 8 characters" />}
            />
          </Form.Item>
          <Button type="primary" htmlType="submit" block loading={isSubmitting}>Register</Button>
        </form>
        <Typography.Paragraph style={{ marginTop: 16 }}>
          Already have an account? <Link to="/login">Sign in</Link>
        </Typography.Paragraph>
      </Card>
    </div>
  );
}

export default RegisterPage;
