import React from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { cn } from '@/lib/utils';
import { Badge } from '@/components/ui/badge';
import { 
  Briefcase, 
  MessageCircle, 
  Plus, 
  Bell, 
  BarChart3,
  Home
} from 'lucide-react';
import { useNotifications } from '@/hooks/useNotifications';
import { useQuery } from '@tanstack/react-query';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/contexts/AuthContext';

interface NavItem {
  key: string;
  label: string;
  icon: React.ComponentType<any>;
  path: string;
  badge?: number;
}

const BottomNavigation: React.FC = () => {
  const location = useLocation();
  const navigate = useNavigate();
  const { user } = useAuth();
  const { pendingCount } = useNotifications();

  // Get unread message count
  const { data: unreadCount = 0 } = useQuery({
    queryKey: ['unread-messages', user?.id],
    queryFn: async () => {
      try {
        if (!user?.id) return 0;
        
        // First, get all conversations the user is part of
        const { data: userConversations, error: conversationsError } = await supabase
          .from('conversations')
          .select('id')
          .or(`client_id.eq.${user.id},provider_id.eq.${user.id}`);
        
        if (conversationsError) {
          console.error('Error fetching user conversations:', conversationsError);
          return 0;
        }
        
        if (!userConversations || userConversations.length === 0) {
          return 0;
        }
        
        // Get conversation IDs
        const conversationIds = userConversations.map(c => c.id);
        
        // Now count unread messages in these conversations
        // Messages where: user is NOT the sender AND read_at is null AND conversation belongs to user
        const { count, error } = await supabase
          .from('messages')
          .select('*', { count: 'exact', head: true })
          .neq('sender_id', user.id) // Messages not sent by current user
          .is('read_at', null) // Messages that haven't been read
          .in('conversation_id', conversationIds); // Only in user's conversations
        
        if (error) {
          console.error('Error fetching unread count:', error);
          return 0;
        }
        
        console.log('Unread messages count:', count);
        return count || 0;
      } catch (error) {
        console.error('Error in unread count query:', error);
        return 0;
      }
    },
    enabled: !!user?.id,
    retry: 1,
    staleTime: 15000, // 15 seconds
    refetchInterval: 15000, // Refetch every 15 seconds for faster updates
    refetchOnWindowFocus: true,
  });

  const navItems: NavItem[] = [
    {
      key: 'home',
      label: 'Home',
      icon: Home,
      path: '/',
    },
    {
      key: 'jobs',
      label: 'Jobs',
      icon: Briefcase,
      path: '/jobs',
    },
    {
      key: 'messages',
      label: 'Messages',
      icon: MessageCircle,
      path: '/messages',
      badge: unreadCount > 0 ? unreadCount : undefined,
    },
    {
      key: 'post',
      label: 'Post Job',
      icon: Plus,
      path: '/post-job',
    },
    {
      key: 'notifications',
      label: 'Notifications',
      icon: Bell,
      path: '/notifications',
      badge: pendingCount > 0 ? pendingCount : undefined,
    },
    {
      key: 'dashboard',
      label: 'Dashboard',
      icon: BarChart3,
      path: '/dashboard',
    },
  ];

  const handleNavigation = (path: string) => {
    navigate(path);
  };

  const isActive = (path: string) => {
    if (path === '/') {
      return location.pathname === '/';
    }
    return location.pathname.startsWith(path);
  };

  return (
    <nav className="fixed bottom-0 left-0 right-0 bg-background border-t border-border z-50 md:hidden">
      <div className="flex items-center justify-around py-2">
        {navItems.map((item) => {
          const Icon = item.icon;
          const active = isActive(item.path);
          
          return (
            <button
              key={item.key}
              onClick={() => handleNavigation(item.path)}
              className={cn(
                "flex flex-col items-center justify-center min-w-0 flex-1 py-2 px-1 relative",
                "transition-colors duration-200",
                active 
                  ? "text-primary" 
                  : "text-muted-foreground hover:text-foreground"
              )}
            >
              <div className="relative">
                <Icon 
                  className={cn(
                    "h-6 w-6 mb-1",
                    active && item.key === 'messages' && unreadCount > 0 && "fill-current",
                    active && item.key === 'notifications' && pendingCount > 0 && "fill-current"
                  )} 
                />
                {item.badge && item.badge > 0 && (
                  <Badge 
                    variant="destructive" 
                    className="absolute -top-2 -right-2 h-5 w-5 flex items-center justify-center p-0 text-xs"
                  >
                    {item.badge > 99 ? '99+' : item.badge}
                  </Badge>
                )}
              </div>
              <span className={cn(
                "text-xs font-medium truncate max-w-full",
                active ? "text-primary" : "text-muted-foreground"
              )}>
                {item.label}
              </span>
            </button>
          );
        })}
      </div>
    </nav>
  );
};

export default BottomNavigation;